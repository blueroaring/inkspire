# 高中异闻：尖塔 0.3.0

尖塔独立战斗游戏。更新后沿用固定用户存档目录，支持游戏内存档迁移。

- Godot 4.7.2，Compatibility 渲染器，Windows x86_64 / Android ARM64 / Web。
- 官网：https://inkspire-game.freemyip.com/
- **Android APK 未经真机测试，不保证能够安装、启动或正常游玩。**
- 此源码和安装包不含作者或玩家存档、战斗报告、缓存、历史构建、制作原图或网站管理凭据。

## 本地运行

先执行 `python tools/setup_local_keys.py`，再用 Godot 4.7.2 打开 `project.godot` 并运行。
开发密钥仅供自己的存档和测试使用，生成的报告不能提交到官方网站。
正式发行所用的报告密钥、Android 签名密钥均不提交 Git。

## 导出

安装 Godot 4.7.2 官方导出模板。Windows：
`godot --headless --path . --export-release Tower-Windows build/InkSpire.exe`

Android 需安装 JDK 17、Android SDK，并在编辑器中配置自己的签名证书。
使用 `Tower-Android` 预设导出 ARM64 release APK；不可使用作者的签名身份。

素材是游戏实际使用的处理后资源；共享脚本保留战斗系统必要的类型与接口。
发布资源使用 WebP（品质 90，小图无损），保留原始分辨率与透明度；PNG 制作母版不重复发布。
源码公开不代表所有素材均以同一开源许可授权；详见 LICENSE.txt、THIRD_PARTY_NOTICES.txt 和 data/tower_legal/。

## 0.3.0 数据说明

通关第 20 层后，发行版退出或进入后台会静默发送匿名战斗统计，只供开发者后台分析，不进榜单。可在设置的隐私区域关闭。不会上传昵称、完整存档、对话或设备身份；离线保留队列，下次启动重试。开发源码默认不连接正式后台。

Web 导出使用 Tower-Web 预设；导出后将 tools/tower_telemetry.js 复制到网页目录并命名为 telemetry.js，服务器提供同源 /api/telemetry 接口。
