# 上板阻塞点定位（2026-10-24 05:15）

之前三条记录都写 `JtagServer-0306: No devices detected`，按提示只能猜"板子未上电 / 排线未接"。
本轮用 `00b_cable_probe.tcl`（只读，不写板子）把范围缩小了一层：

```
Executing : cfg_connect -ip 127.0.0.1 -port 65420
Connect to server[127.0.0.1 : 65420] successfully.
COMMAND[check version information] execute successfully
The cable List :          <-- 空！
COMMAND[get_cable_paras] execute successfully
```

**结论：不是"器件没响应"，而是"连下载线都没有被枚举"。**
`The cable List` 为空意味着 USB 下载线（或它的驱动）在 JtagServer 里根本没出现，
所以 `cfg_scan_chain` 必然报 `No devices detected`。

要恢复上板验证，需要（按顺序查）：
1. USB 下载线是否插在主机上（不是只插在板子那端）；
2. 设备管理器里是否出现 Pango/FTDI/CH347 设备 —— 没出现就装
   `pds/PDS_2022.2-SP6.1/driver/` 下的驱动（`dpinst-amd64.exe`）；
3. 装完重起 `cdt_js.exe -port 65420`，再跑

```
PANGO_JTAG_PORT=65420 cdt_cfg.exe -file 00b_cable_probe.tcl -ip 127.0.0.1 -port 65420 -work_dir .
```

`The cable List` 里出现条目之后，才轮到"板子是否上电"这一层。

> 注意：`00_scan_chain.tcl` 内部写死 `set port "51015"`，命令行 `-port` 会被它盖掉，
> 必须用环境变量 `PANGO_JTAG_PORT` 覆盖（lesson 91）。
