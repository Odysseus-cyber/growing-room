# 会长大的房间 · Growing Room

独立 H5 项目的开发环境与基础 Phaser 场景。当前页面用于验证渲染、输入、响应式布局及热更新，完整游戏玩法尚未实现。

## 快速开始

需要 macOS Apple Silicon、系统自带 Bash/curl/tar，以及首次安装时可访问 Node.js 官方站点和 npm 仓库的网络。无须在系统中安装 Node 或 npm。

```sh
cd /Users/admin/Documents/Games/growing-room
./dev setup
./dev start
```

浏览器打开 **http://127.0.0.1:5173**。看到“环境已就绪”后，点击房间或“打个招呼”按钮，应出现角色和文字反馈。修改 `src/` 内文件后，Vite 会自动更新页面。开发服务在前台运行，按 **Ctrl-C** 停止。

请固定使用上述地址。`localhost` 和 `127.0.0.1` 属于不同浏览器来源，存档不共享；端口被占用时启动会失败，不会偷偷换端口。

## 项目工具链

| 工具 | 固定版本 |
| --- | --- |
| Node.js | 24.22.2，官方 darwin-arm64 包 |
| npm | 11.19.1，随上述 Node 包附带 |
| Phaser | 4.2.1 |
| TypeScript | 7.0.2 |
| Vite | 8.3.7 |

`package-lock.json` 固定完整依赖树。`./dev setup` 使用 `npm ci --include=dev` 恢复，不自动升级依赖；锁文件缺失会明确报错，需要先恢复锁文件。项目独立使用官方 Node，不依赖 Codex 内置工具链路径。

入口只对当前进程临时设置 PATH、npm 配置、缓存和临时目录，不修改系统 Node、全局 npm、`~/.npmrc` 或终端启动配置。项目 npm 不读取用户级 npmrc；项目公共配置位于 `.npmrc`。无需全局安装 Vite、TypeScript 或 Phaser。

日常启动、检查和构建均使用 `./dev`，无须手动设置环境变量。新增或升级依赖属于显式维护操作，应沿用 `scripts/environment.sh` 中的项目 npm 配置，同时更新 `package.json` 和锁文件，再运行检查与构建。

## 目录与清理边界

```text
src/                    游戏源码、样式与场景
public/assets/          游戏美术与音效
scripts/                环境管理和回归检查
.dev/runtime/           项目独立 Node 与 npm
.dev/cache/downloads/   官方运行时下载缓存
.dev/cache/npm/         npm 包及日志缓存
.dev/cache/vite/        Vite 预构建缓存
.dev/cache/tmp/         项目工具临时文件
.dev/cache/xdg/         使用 XDG 标准的工具缓存
.dev/run/               本项目开发服务运行记录
node_modules/           锁定的依赖安装结果
dist/                   H5 发布包
```

`.dev/`、`node_modules/`、`dist/` 均已加入 `.gitignore`。运行记录会在正常退出时移除；异常退出留下的记录在下次操作确认对应进程退出后清理。

| 命令 | 作用 |
| --- | --- |
| `./dev setup` | 安装或恢复运行时和依赖 |
| `./dev start` | 在固定地址启动开发服务 |
| `./dev check` | 检查 Node、npm、依赖与 TypeScript |
| `./dev build` | 类型检查并生成 `dist/` |
| `./dev clean cache` | 删除下载、npm、Vite、临时文件等缓存 |
| `./dev clean deps` | 仅删除 `node_modules/` |
| `./dev clean build` | 仅删除 `dist/` |
| `./dev clean runtime` | 仅删除项目内 Node/npm |
| `./dev clean all` | 删除上述全部可重建内容 |

清理前先停止开发服务。`setup` 会重建依赖，也要求开发服务停止。命令只处理固定项目目录；如管理目录被替换为符号链接，会拒绝操作。清理入口使用系统 Bash，即使 Node 已移除仍可运行。

**所有清理操作都保留源码、资产、配置、锁文件及 `.env.local`。** 浏览器 localStorage/IndexedDB 属于浏览器，不会由环境脚本清理。当前样板尚未实现游戏存档。

重新开始开发：

```sh
./dev setup
./dev start
```

只清理缓存或构建产物后，如果运行时和依赖还在，可以直接启动；清理依赖、运行时或全部环境后，需要先执行 `setup`。保留下载缓存时可直接恢复 Node；npm 缓存是否足够离线恢复取决于所需包是否完整缓存。

## 验证与发布包

```sh
./dev check
./dev build
/bin/bash scripts/test-environment.sh
```

环境回归检查在独立临时目录进行，覆盖模块化清理、源文件和本地配置保留、符号链接边界、运行中服务保护，不会清理实际项目环境。

`dist/` 是可部署的 H5 静态产物，资源路径使用相对路径。通过 HTTP 服务访问，不使用 `file://` 直接打开。TapTap 账号、云存档 SDK 和发布工具在发布阶段接入，当前不安装，也不在源码中保存凭据。

后续迁移项目时，可仅复制源码、资产、脚本、配置和锁文件，再执行 `./dev setup`；下载缓存、依赖和发布包可按需重新生成。
