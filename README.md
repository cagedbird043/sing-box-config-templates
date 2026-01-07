# Windows 11 Sing-Box 部署完成指南 (Split Architecture)

恭喜！您的 Sing-Box 服务已成功部署到 Windows 11 上。系统采用了 **Git 仓库与运行时分离** 的架构，既保证了配置管理的整洁，又确保了服务的稳定性。

## 🚀 快速上手

您现在的 Windows Terminal 已经拥有了 `sbc` 命令（PowerShell 别名）。

### 疑难解答
- **端口冲突**: 确保没有其他程序（如 Clash Verge）占用 7890 端口。
- **日志乱码**: PowerShell 默认已处理 UTF-8，如遇乱码请尝试 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`。
- **Git 冲突**: 如果手动修改了包含 Git 的文件，`sbc update` 可能会因冲突失败。建议保持本地仓库干净，仅通过修改 `.env` 自定义。
- **启动失败 (Subscription 404)**: 如果日志显示 `unexpected status: 404 Not Found`，说明 `.env` 中的订阅链接失效。Sing-box 默认冷启动必须成功下载订阅。请更新 `.env` 后运行 `sbc render` 和 `sbc restart`。


| 命令 | Linux (Bash) | Windows (PowerShell) | 说明 |
| :--- | :--- | :--- | :--- |
| **状态** | `sbc status` | `sbc status` | 查看服务运行状态 |
| **更新** | `sbc update` | `sbc update` | 拉取最新代码(Repo)、更新二进制(Scoop)、渲染配置并重启 |
| **重启** | `sbc restart` | `sbc restart` | 仅重启服务 |
| **日志** | `sbc log` | `sbc log` | 实时查看运行日志 (Tail -f) |
| **检查** | `sbc check` | `sbc check` | 语法检查 |

## 📂 目录结构（分离架构）

为了防止 Git 操作干扰运行，我们将文件分为了两个目录：

### 1. 运行时目录 (`~/.config/sing-box`)
**这是服务的“家”，存放所有私密和运行时的文件。**
```powershell
C:\Users\Mice\.config\sing-box\
├── .env                  # [私密] 核心密钥与机场订阅
├── config.json           # [自动生成] 也就是 Sing-box 实际读取的配置
├── sing-box.exe          # [Binary] 主程序
├── sing-box-service.xml  # [Config] WinSW 服务定义
├── sing-box.out.log      # [Log] 运行日志
└── sing-box-service.wrapper.log
```

### 2. 代码仓库目录 (`~/sing-box-repo`)
**这是 Git 管理的区域，存放模板和脚本。**
```powershell
C:\Users\Mice\sing-box-repo\
├── .git/                 # Git 版本控制
├── config.template.json  # 配置模板 (修改这里，然后运行 sbc update)
├── sbc.ps1               # 控制脚本源码
└── sing-box.json         # Scoop Manifest
```

> **注意**: `~/.local/bin/sbc.ps1` 是一个指向 `~/sing-box-repo/sbc.ps1` 的**软链接**。这意味着您在 Repo 中拉取的脚本更新会立即生效。

## 🔧 常见维护场景

### 修改订阅或密钥
1. 编辑 `C:\Users\Mice\.config\sing-box\.env`。
2. 运行 `sbc restart`。

### 修改配置结构 (如增加路由规则)
1. 编辑 `C:\Users\Mice\sing-box-repo\config.template.json`。
2. 运行 `sbc update` (这会拉取最新代码并利用新模板重新生成 `config.json`)。

### 手动更新 Sing-box 版本
如果 Scoop 自动更新失败：
1. 下载新的 zip 包。
2. 解压并将 `sing-box.exe` 覆盖到 `C:\Users\Mice\.config\sing-box\sing-box.exe`。
3. 运行 `sbc restart`。

---
**Enjoy your professional, structured proxy service!**
