# sing-box-config-templates

[![Configuration](https://img.shields.io/badge/config-decoupled-blue)](https://github.com/Mice-Tailor-Infra/sing-box-config-templates)

本项目是个人 **Sing-box** 跨平台配置文件的上游模板仓库。

采用 **IaC (Infrastructure as Code)** 思想管理网络配置，通过分支策略适配不同硬件环境（Android/Linux/Windows），并实现了配置逻辑与敏感凭证的完全解耦。

## ✨ 核心架构亮点

- **全端脱敏架构 (Decoupled Secrets)**

  - 仓库内仅包含逻辑模板 (`config.template.json`)，不包含任何私人订阅链接或密钥。
  - 运行时通过 `envsubst` 动态注入环境变量生成最终配置，确保 Git 历史绝对清白。

- **多分支环境隔离**

  - `main`: 通用 Linux 生产环境配置，追求极致的路由稳定性。
  - `mobile`: Android (ColorOS) 深度适配版。包含 **VoLTE/VoNR 物理隔离**（通过 `exclude_package`）、FCM 唤醒优化及针对移动端基带的功耗控制。
  - `win11`: Windows 桌面端适配版，针对虚拟网卡特性关闭了不必要的重定向参数。

- **路由逻辑工程化**
  - **白名单防御机制**：在移动端采用激进的 `exclude_package` 策略，仅接管核心代理流量，物理规避国内应用、银行软件及系统组件的审计风险。
  - **DNS 策略优化**：强制 `ipv4_only` 策略以解决复杂的双栈回退延迟，配合独立缓存机制提升解析效率。
  - **多机场负载均衡**：预置三路订阅源的故障转移与自动择优策略。

## 🛠️ 使用指南

本仓库通常作为 **KernelSU/Magisk 模块** 或 **CI/CD 流水线** 的上游子模块使用。

### 手动生成配置（Linux/MacOS）

依赖工具：`gettext` (提供 `envsubst` 命令)

1. 复制环境变量模板：

   ```bash
   cp .env.example .env
   # 编辑 .env 填入您的真实订阅链接和密钥
   vim .env
   ```

2. 渲染配置文件：

   ```bash
   # 加载环境变量并渲染
   set -a && source .env && set +a
   envsubst < config.template.json > config.json
   ```

3. 启动 Sing-box：
   ```bash
   sing-box run -c config.json
   ```

## ⚠️ 免责声明

本项目仅供技术研究与系统工程实验使用。使用者应遵守当地法律法规。
