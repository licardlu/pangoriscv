/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "gpio.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* ==========================================================================
 * 四路舵机中继（FPGA 出 PWM 指令，STM32 重新生成干净的 PWM）
 *
 *   FPGA 四路是"一直在发"的 50Hz PWM：0.5ms=0度(关)，1.5ms=90度(开)，
 *   反装的那两路这两个脉宽是对调的（RTL 里 SERVO_REVERSED_MASK）。
 *   STM32 量出脉宽 -> 判出"这个桶现在该不该开" -> 自己重发动作：
 *       关到位 --1s--> 开到位 --保持5s--> 关到位
 *   全程 20ms 周期不变，只有高电平宽度变。上电第一件事就是关到位。
 * ========================================================================== */

/* -------- 舵机行程与时间，想调手感就改这几个数 -------- */
#define SERVO_NUM               4U
#define SERVO_PULSE_0DEG_US     500U     /* 0 度：0.5ms */
#define SERVO_PULSE_90DEG_US    1500U    /* 90 度：1.5ms */
#define SERVO_FRAME_US          20000U   /* 20ms 一帧，所有角度都一样 */
#define SERVO_FRAME_MS          20U

/* 反装的那几路输出取反用：out = 2000 - pulse。500 + 1500 = 2000 */
#define SERVO_PULSE_SUM         (SERVO_PULSE_0DEG_US + SERVO_PULSE_90DEG_US)

#define SERVO_STEP_US           20U      /* 每帧走 20us：0->90 约 1.0 秒 */
#define SERVO_HOLD_MS           5000U    /* 到 90 度停 5 秒 */
#define SERVO_REARM_MS          100U     /* 关到位后，输入要回到 0 持续 100ms 才允许再触发 */

/* 0 = 只在输入 0->1 的上升沿触发一次（推荐，FPGA 一直给 1 也只开一次）
 * 1 = 输入一直是 1 就一直反复开合（调试用） */
#define SERVO_RETRIG_WHILE_HIGH 0

/* -------- 接线（按现场实测的针序） --------
 *   PB12 <- 蓝 U16 / J3.27      PA0 -> 蓝桶舵机
 *   PB13 <- 灰 U15 / J3.28      PA1 -> 灰桶舵机
 *   PB14 <- 红 AC26 / J3.29     PA2 -> 红桶舵机
 *   PB15 <- 绿 AB26 / J3.30     PA3 -> 绿桶舵机
 */

/* -------- FPGA 指令线的极性 --------
 * 哪位是 1，就表示那一路 FPGA 发的是"窄=开"（RTL 里开了 REVERSED_MASK）。
 * 板上这版 build_servo_repair_20261103 该参数没接，默认 4'b0000，所以填 0。
 * 只有当"上电后慢慢转开、答题时慢慢关上"时才需要动它——那是识别判反了，
 * 和下面舵机方向反（上电一下就弹开）不是一回事。
 */
#define SERVO_IN_MASK           0x0U

/* -------- 每一路舵机的转动方向 --------
 * 0 = 正常：500us 是关（向里合盖），1500us 是开（向外翻）
 * 1 = 反了：1500us 才是关，500us 才是开（这只舵机转向跟别人相反）
 *
 * 现场实测：蓝桶关得很好；绿桶（厨余）上电往外翻，说明它方向反，要置 1。
 */
#define SERVO_REV_BLUE          1
#define SERVO_REV_GRAY          0
#define SERVO_REV_RED           1
#define SERVO_REV_GREEN         1

#define SERVO_OUT_MASK          ((SERVO_REV_BLUE  << 0) | \
                                 (SERVO_REV_GRAY  << 1) | \
                                 (SERVO_REV_RED   << 2) | \
                                 (SERVO_REV_GREEN << 3))

/* -------- FPGA 指令线怎么判：只能量脉宽，不能看"有没有波形" --------
 * 四路空闲时也在发 0.5ms 脉冲，所以"有波形"恒为真。
 * 每 100us 采一次，20ms 一个窗口共 200 个点：
 *   1.5ms  -> 15~16 个高电平点 -> 宽 -> 1
 *   0.5ms  ->  5~6  个          -> 窄 -> 0
 *   没波形 ->  0~2  个          -> 当作 0（关）
 */
#define IN_SAMPLE_US            100U
#define IN_SAMPLES_PER_FRAME    200U
#define IN_NO_SIG_CNT           2U       /* <=2 点：没波形 */
#define IN_NARROW_CNT           8U       /* <=8 点：窄脉冲 0.5ms */
#define IN_WIDE_CNT             12U      /* >=12 点：宽脉冲 1.5ms */
#define IN_CONFIRM_FRAMES       3U       /* 连续 3 帧(60ms)一致才认，滤掉翻转和毛刺 */

/* 1 = 不接 FPGA 也能自检：四路轮流开，每路 10 秒 */
#define SERVO_SELFTEST          0

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/

/* USER CODE BEGIN PV */

typedef enum
{
  SERVO_CLOSED = 0,   /* 停在 0 度 */
  SERVO_OPENING,      /* 0 度 -> 90 度 */
  SERVO_HOLDING,      /* 90 度保持 */
  SERVO_CLOSING       /* 90 度 -> 0 度 */
} ServoState_t;

typedef struct
{
  ServoState_t state;
  uint16_t pulse_us;    /* 当前脉宽 */
  uint16_t hold_ms;     /* 已在 90 度停留的时间 */
  uint16_t rearm_ms;    /* 输入保持为 0 的时间 */
  uint8_t  cmd;         /* 消抖之后的指令 0/1 */
  uint8_t  raw;         /* 本帧原始判定 */
  uint8_t  raw_cnt;     /* 连续相同帧数 */
} ServoCh_t;

static ServoCh_t g_servo[SERVO_NUM];

static volatile uint16_t g_in_cnt[SERVO_NUM];    /* 每 20ms 存一次：窗口内高电平点数 */
static volatile uint8_t  g_frame_flag;           /* 新的一帧到了 */
static volatile uint16_t s_hi_cnt[SERVO_NUM];    /* 窗口内高电平采样点个数 */
static volatile uint16_t s_sample_idx;

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
/* USER CODE BEGIN PFP */
static void Servo_Init(void);
static void Servo_Task(void);
static volatile uint32_t *Servo_CcrReg(uint8_t ch);
/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{
  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  /* USER CODE BEGIN 2 */
  Servo_Init();

  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
    if (g_frame_flag != 0U)
    {
      g_frame_flag = 0U;
      Servo_Task();          /* 每 20ms 走一步，和 PWM 周期对齐 */
    }
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
  RCC_OscInitStruct.HSEState = RCC_HSE_ON;
  RCC_OscInitStruct.HSEPredivValue = RCC_HSE_PREDIV_DIV1;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
  RCC_OscInitStruct.PLL.PLLMUL = RCC_PLL_MUL9;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV2;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_2) != HAL_OK)
  {
    Error_Handler();
  }
}

/* USER CODE BEGIN 4 */

/* TIM3：100us 采样中断，统计 4 路指令线在 20ms 窗口里的高电平个数 */
void TIM3_IRQHandler(void)
{
  if ((TIM3->SR & TIM_SR_UIF) != 0U)
  {
    TIM3->SR = ~TIM_SR_UIF;

    {
      uint16_t idr = (uint16_t)GPIOB->IDR;

      if ((idr & GPIO_PIN_12) != 0U) { s_hi_cnt[0]++; }
      if ((idr & GPIO_PIN_13) != 0U) { s_hi_cnt[1]++; }
      if ((idr & GPIO_PIN_14) != 0U) { s_hi_cnt[2]++; }
      if ((idr & GPIO_PIN_15) != 0U) { s_hi_cnt[3]++; }
    }

    s_sample_idx++;
    if (s_sample_idx >= IN_SAMPLES_PER_FRAME)
    {
      uint8_t i;

      s_sample_idx = 0U;
      for (i = 0U; i < SERVO_NUM; i++)
      {
        g_in_cnt[i] = s_hi_cnt[i];   /* 只存点数，怎么判交给 Servo_Task */
        s_hi_cnt[i] = 0U;
      }
      g_frame_flag = 1U;
    }
  }
}

static volatile uint32_t *Servo_CcrReg(uint8_t ch)
{
  switch (ch)
  {
    case 0U:  return &TIM2->CCR1;
    case 1U:  return &TIM2->CCR2;
    case 2U:  return &TIM2->CCR3;
    default:  return &TIM2->CCR4;
  }
}

/* 上电先全部压到"关到位"再开定时器，避免上电瞬间抽一下 */
static void Servo_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  uint8_t i;

  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();
  __HAL_RCC_AFIO_CLK_ENABLE();
  __HAL_AFIO_REMAP_TIM2_DISABLE();   /* PA0..PA3 = TIM2_CH1..CH4，不重映射 */
  __HAL_AFIO_REMAP_TIM3_DISABLE();   /* TIM3 只用它的更新中断，引脚不占用 */

  /* ---- 4 路舵机 PWM 输出：PA0 / PA1 / PA2 / PA3 ---- */
  GPIO_InitStruct.Pin   = GPIO_PIN_0 | GPIO_PIN_1 | GPIO_PIN_2 | GPIO_PIN_3;
  GPIO_InitStruct.Mode  = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_HIGH;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  /* ---- 4 路 FPGA 指令输入：PB12 / PB13 / PB14 / PB15，下拉 ----
   * 下拉是为了 FPGA 没配置、线掉了的时候读成 0，不会自己乱开。
   */
  GPIO_InitStruct.Pin  = GPIO_PIN_12 | GPIO_PIN_13 | GPIO_PIN_14 | GPIO_PIN_15;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_PULLDOWN;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /* ---- 状态机初值：全部停在 0 度 ---- */
  for (i = 0U; i < SERVO_NUM; i++)
  {
    g_servo[i].state     = SERVO_CLOSED;
    g_servo[i].pulse_us  = SERVO_PULSE_0DEG_US;
    g_servo[i].hold_ms   = 0U;
    g_servo[i].rearm_ms  = SERVO_REARM_MS;   /* 上电如果指令已经是 1，允许直接开 */
    g_servo[i].cmd       = 0U;
    g_servo[i].raw       = 0U;
    g_servo[i].raw_cnt   = 0U;
  }

  /* ---- TIM2：1us 一个计数，20ms 一帧，四路 PWM ---- */
  __HAL_RCC_TIM2_CLK_ENABLE();

  TIM2->CR1   = 0U;
  TIM2->CNT   = 0U;
  TIM2->PSC   = 71U;                    /* 72MHz / 72 = 1MHz */
  TIM2->ARR   = SERVO_FRAME_US - 1U;    /* 20000us = 20ms */
  /* 上电就写"关到位"的值；反装的那几路要写 1.5ms，
   * 否则最先的 20ms 里那两只舵机会先弹一下再回来 */
  for (i = 0U; i < SERVO_NUM; i++)
  {
    if (((SERVO_OUT_MASK >> i) & 1U) != 0U)
    {
      *Servo_CcrReg(i) = SERVO_PULSE_SUM - SERVO_PULSE_0DEG_US;
    }
    else
    {
      *Servo_CcrReg(i) = SERVO_PULSE_0DEG_US;
    }
  }
  /* OCxM = 110 是 PWM1 模式，OCxPE = 1 打开预装载，改占空比不会出半个怪波形 */
  TIM2->CCMR1 = (6U << 4) | (1U << 3) | (6U << 12) | (1U << 11);
  TIM2->CCMR2 = (6U << 4) | (1U << 3) | (6U << 12) | (1U << 11);
  TIM2->CCER  = TIM_CCER_CC1E | TIM_CCER_CC2E | TIM_CCER_CC3E | TIM_CCER_CC4E;
  TIM2->EGR   = TIM_EGR_UG;             /* 把上面写的 CCR 一次性装进影子寄存器 */
  TIM2->CR1   = TIM_CR1_ARPE | TIM_CR1_CEN;

  /* ---- TIM3：100us 采样节拍，只开更新中断 ---- */
  __HAL_RCC_TIM3_CLK_ENABLE();

  TIM3->CR1  = 0U;
  TIM3->PSC  = 71U;                     /* 1MHz */
  TIM3->ARR  = IN_SAMPLE_US - 1U;       /* 100us */
  TIM3->EGR  = TIM_EGR_UG;
  TIM3->SR   = 0U;                      /* 清掉 UG 产生的 Update 标志 */
  TIM3->DIER = TIM_DIER_UIE;

  HAL_NVIC_SetPriority(TIM3_IRQn, 1U, 0U);
  HAL_NVIC_EnableIRQ(TIM3_IRQn);

  TIM3->CR1  = TIM_CR1_CEN;
}

/* 每 20ms 调一次：先认指令，再推状态机，最后写 CCR */
static void Servo_Task(void)
{
  uint8_t i;

  for (i = 0U; i < SERVO_NUM; i++)
  {
    ServoCh_t *s = &g_servo[i];

    uint8_t in;

#if (SERVO_SELFTEST != 0)
    /* 自检模式：不接 FPGA，四路轮流各给 10 秒 1 */
    in = (((HAL_GetTick() / 10000U) % SERVO_NUM) == i) ? 1U : 0U;
#else
    {
      uint8_t  inbit = (uint8_t)((SERVO_IN_MASK >> i) & 1U);
      uint16_t cnt   = g_in_cnt[i];

      if (cnt <= IN_NO_SIG_CNT)
      {
        in = 0U;                        /* 完全没波形：当关，防悬空误开 */
      }
      else if (cnt <= IN_NARROW_CNT)
      {
        in = inbit;                     /* 窄 0.5ms：正常路=0，反装路=1 */
      }
      else if (cnt >= IN_WIDE_CNT)
      {
        in = (uint8_t)(inbit ^ 1U);     /* 宽 1.5ms：正常路=1，反装路=0 */
      }
      else
      {
        in = s->raw;                    /* 卡在中间就保持上一帧，不跟着抖 */
      }
    }
#endif

    /* ---- 指令消抖：连续 IN_CONFIRM_FRAMES 帧一致才认 ---- */
    if (in == s->raw)
    {
      if (s->raw_cnt < 255U)
      {
        s->raw_cnt++;
      }
    }
    else
    {
      s->raw     = in;
      s->raw_cnt = 0U;
    }
    if (s->raw_cnt >= IN_CONFIRM_FRAMES)
    {
      s->cmd = s->raw;
    }

    /* ---- 四态状态机 ---- */
    switch (s->state)
    {
      case SERVO_CLOSED:
        s->pulse_us = SERVO_PULSE_0DEG_US;

        if (s->cmd == 0U)
        {
          if (s->rearm_ms < SERVO_REARM_MS)
          {
            s->rearm_ms += SERVO_FRAME_MS;
          }
        }

        if (s->cmd != 0U)
        {
#if (SERVO_RETRIG_WHILE_HIGH != 0)
          s->state = SERVO_OPENING;      /* 电平触发：只要还是 1 就再开一轮 */
          s->rearm_ms = 0U;
#else
          if (s->rearm_ms >= SERVO_REARM_MS)
          {
            s->state    = SERVO_OPENING; /* 上升沿触发：开一轮就完事 */
            s->rearm_ms = 0U;
          }
#endif
        }
        break;

      case SERVO_OPENING:
        if ((uint32_t)s->pulse_us + SERVO_STEP_US >= SERVO_PULSE_90DEG_US)
        {
          s->pulse_us = SERVO_PULSE_90DEG_US;
          s->hold_ms  = 0U;
          s->state    = SERVO_HOLDING;
        }
        else
        {
          s->pulse_us += SERVO_STEP_US;
        }
        break;

      case SERVO_HOLDING:
        s->pulse_us = SERVO_PULSE_90DEG_US;
        s->hold_ms += SERVO_FRAME_MS;
        if (s->hold_ms >= SERVO_HOLD_MS)
        {
          s->state = SERVO_CLOSING;
        }
        break;

      case SERVO_CLOSING:
        if (s->pulse_us <= SERVO_PULSE_0DEG_US + SERVO_STEP_US)
        {
          s->pulse_us  = SERVO_PULSE_0DEG_US;
          s->rearm_ms  = 0U;
          s->state     = SERVO_CLOSED;
        }
        else
        {
          s->pulse_us -= SERVO_STEP_US;
        }
        break;

      default:
        s->pulse_us = SERVO_PULSE_0DEG_US;
        s->state    = SERVO_CLOSED;
        break;
    }

    /* ---- 写比较寄存器：反装的那几路把 0.5/1.5ms 对调 ---- */
    if (((SERVO_OUT_MASK >> i) & 1U) != 0U)
    {
      *Servo_CcrReg(i) = SERVO_PULSE_SUM - s->pulse_us;
    }
    else
    {
      *Servo_CcrReg(i) = s->pulse_us;
    }
  }
}

/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the source file name and the source line number where
  *         the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
