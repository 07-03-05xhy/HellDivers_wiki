# 绝地潜兵2 Wiki App — 架构契约

## 数据源
- API: `https://helldivers.wiki.gg/zh/api.php`（MediaWiki 1.43.6，GET + JSON）
- 条目链接: `https://helldivers.wiki.gg/zh/wiki/<标题>`
- 图片: `https://helldivers.wiki.gg/zh/Special:FilePath/<文件名>?width=N`
- 所有请求必须带 UA: `kWikiUserAgent`（见 lib/data/wiki_models.dart）

### 已验证的关键 API 调用
| 功能 | 调用 |
|---|---|
| 分类列表 | `action=query&list=allcategories&aclimit=50&format=json` → `query.allcategories[].{'*', 'pages'}`（按 pages 降序由客户端排序） |
| 分类成员 | `action=query&list=categorymembers&cmtitle=Category:X&cmtype=page&cmlimit=50&cmcontinue=...` → `query.categorymembers[]` + `continue.cmcontinue` |
| 搜索 | `action=query&list=search&srsearch=<词>&srlimit=20` → `query.search[].{pageid,title,snippet}` |
| 条目正文 | `action=parse&page=<标题>&prop=text\|sections\|displaytitle&formatversion=2` → `parse.{pageid,title,text,sections[]}`。注意 displaytitle 可能含 HTML span，需剥离标签 |
| 题图 | `action=query&prop=pageimages&titles=A\|B&pithumbsize=320&formatversion=2` → `query.pages[].thumbnail.source` |

注意：该站分类名多为英文（如 `Category:Weapons`），条目正文为中文与英文混合，属正常现象。

## 模块与写入范围（团队纪律：不得越界改他人文件）
| 文件/目录 | 负责人 |
|---|---|
| pubspec.yaml, analysis_options.yaml, lib/main.dart, lib/theme/hd_theme.dart, lib/data/wiki_models.dart, lib/data/wiki_repository.dart, docs/ | Lead（集成时改） |
| lib/data/wiki_api_client.dart, lib/data/local_store.dart, lib/data/wiki_repository_impl.dart, test/data/ | data-dev |
| lib/ui/, lib/theme/hd_widgets.dart, test/ui/ | ui-dev |

## 接口要点
- `WikiRepository`（lib/data/wiki_repository.dart）是唯一数据入口，UI 层经 Provider 注入获取。
- data-dev 必须提供：`class WikiRepositoryImpl implements WikiRepository`，含无参构造（main.dart 以 `WikiRepositoryImpl()` 创建）。
- ui-dev 必须提供：`lib/ui/pages/home_page.dart` 导出 `class HomePage extends StatelessWidget`（const 构造）。
- 页面导航用 Navigator push MaterialPageRoute；ui-dev 内部页面自行组织。
- flutter_html 渲染正文，样式定制为 HD 主题；条目内链点击跳转应用内条目页。

## 验收
1. `flutter analyze` 零错误零警告（strict-casts / strict-inference 已开启）
2. `flutter test` 全部通过
3. 主流程：首页 → 分类/搜索 → 条目详情（含图片与目录）→ 收藏/历史
