# 绝地潜兵2 Wiki

绝地潜兵2 中文 Wiki（helldivers.wiki.gg/zh）安卓阅读器：不打开网站即可浏览分类、搜索、阅读条目，支持收藏与浏览历史，附武器/战备/敌人图鉴专项视图。

- 技术栈：Flutter（Android），flutter_html 原生渲染正文
- 数据源：MediaWiki 公开 API `https://helldivers.wiki.gg/zh/api.php`（无需登录/令牌）
- UI：绝地潜兵2 游戏终端风（黄黑 HUD，等宽字体，折角面板）

## 功能

- 首页：分类入口网格 + 最近浏览
- 分类浏览：分页加载，题图缩略图
- 条目详情：目录抽屉锚点跳转、正文内链应用内跳转、收藏切换
- 全文搜索：输入即搜（400ms 防抖），命中词黄色高亮
- 图鉴专项：武器 / 战备 / 敌人 / 护甲 / 任务 五个 Tab 卡片网格
- 收藏夹（左滑删除）与浏览历史（可清空），SQLite 本地持久化

## 构建

需要 Flutter 3.47+（本项目在 Flutter 3.47.7 stable 上开发）与 Android SDK。

```powershell
cd <本项目目录>
flutter pub get          # 国内网络可先设镜像：
                         # $env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
                         # $env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
flutter analyze          # 静态检查
flutter test             # 37 项单元/组件测试
flutter run              # 连接设备调试运行
flutter build apk --release        # 正式包
flutter build apk --split-per-abi  # 按 ABI 分包（体积更小）
```

说明：
- `pubspec.yaml` 中 `dependency_overrides: html: 0.15.6` 是为兼容 flutter_html 3.0.0 的必要固定，请勿移除。
- 首次启动需联网下载正文与图片（wiki.gg 服务器在海外，如加载慢属网络原因，应用未内置代理）。

## 架构

详见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。分层：UI（lib/ui/）→ 仓库接口（lib/data/wiki_repository.dart）→ API 客户端 + SQLite（lib/data/）。主题令牌在 lib/theme/hd_theme.dart，HD 风组件库在 lib/theme/hd_widgets.dart。
