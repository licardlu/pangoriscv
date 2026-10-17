# 把本地仓库推送到 GitHub 私有仓库（一次性）

本机没有 `gh` CLI，所以远端仓库需要在浏览器里创建，剩下的步骤这里全包了。

## 0. 前提

- 本地仓库已经建好，`main` 分支已有首次提交（本脚本会自动检查）；
- 提交身份已配置：`git config --global user.name / user.email`；
- 能访问 https://github.com 并已登录。

## 1. 在浏览器里建空仓库

1. 右上角 **+ → New repository**
2. **Repository name**：`pangoriscv`
3. **Visibility**：选 **Private**
4. **不要**勾 *Add a README file* / *.gitignore* / *license*（本地已有，勾了会产生无关提交）
5. **Create repository**，复制页面上的 HTTPS 地址，形如
   `https://github.com/<你的用户名>/pangoriscv.git`

## 2. 添加远端并推送

```powershell
cd E:\file\pango\project
powershell -ExecutionPolicy Bypass -File scripts\setup_remote.ps1 -RemoteUrl https://github.com/<你的用户名>/pangoriscv.git
```

脚本做的事：检查工作区无未提交改动 → `git remote add origin <url>`（已存在则改为 set-url）→
`git push -u origin main`。

**首次推送会弹 GitHub 登录窗口**（Git Credential Manager）：选 *Sign in with your browser* 即可，
不需要手动生成 token。若窗口没弹出来而提示密码，去
https://github.com/settings/tokens 生成一个 **classic token（勾 `repo`）** 粘到“密码”处。

## 3. 邀请同学

网页进入仓库 → **Settings → Collaborators → Add people** → 输入同学的 GitHub 用户名 →
同学在自己的 GitHub 通知里**接受邀请**。

接受后同学克隆：

```powershell
git clone https://github.com/<你的用户名>/pangoriscv.git
cd pangoriscv
```

## 4. 验证

```powershell
git remote -v
git log --oneline -3
git status          # 应为 "working tree clean"
```

网页刷新仓库首页，应能看到 `README.md`、`firmware/`、`docs/`、`evidence/`、`bitstream/` 等目录。

## 常见问题

| 现象 | 处理 |
|---|---|
| `remote origin already exists` | 脚本已处理（改成 set-url）；手动可用 `git remote set-url origin <url>` |
| `rejected ... fetch first` | 远端被别处改过：`git pull --rebase origin main` 后再 `git push` |
| 推送很慢 / 超时 | 仓库约 5 MB，正常几秒；卡住多为网络，重试一次或换网络 |
| 误提交了大文件（位流/仿真库） | `git rm --cached <路径>`，把规则补进 `.gitignore`，再 `git commit --amend` 后推送 |
| 想要主干保护（以后才需要） | Settings → Branches → Add branch protection rule，勾 *Require a pull request before merging* |
