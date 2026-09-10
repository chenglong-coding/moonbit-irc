# IRC 协议核心

IRC 消息、IRCv3 tags 和受限增量行解析。本地候选版 0.3.0，供比较和代码审查；尚未作为完整竞赛作品提交。

## 运行

安装 MoonBit 后在本目录执行：

```sh
moon check
moon test
moon run cmd/main
```

也可在本目录运行 `./verify.ps1` 验证本项目。`pkg.generated.mbti` 是真实工具链生成的公共 API。命名空间 `localreview` 仅用于本地，正式发布前应替换为申请人的账号。

## 本版范围

实现目标：prefix、command、params、tags 转义、CRLF framing。

未承诺：TCP/TLS、SASL、服务器状态缓存、真实服务器互通。

## 来源与实现方式

规格/算法参考：https://modern.ircdocs.horse/。

当前代码是本地新写的 MoonBit 实现，不声称是上游完整移植；未复制上游源代码、词库或测试集。测试输入为本项目新写。MIT 仅适用于本目录原创代码。将来如移植上游文件，需要另行保存其版权声明并核查许可证，不能直接沿用当前说明。

## 审查

先看 `cmd/main/main.mbt` 的实际使用，再看公共 API 与测试文件。联网兼容性、性能数据或官方验收未执行的部分不得从本地单元测试成功推断。

## 下一阶段与明确限制

增加真实 TCP/TLS 客户端、CAP/SASL、昵称/频道状态及 IRCv3 tag key 更完整验证；当前要求 UTF-8，历史服务器的其他编码不在本版范围。

本分装包自带 `web/index.html`（用 `start-review.ps1` 启动）。`cmd/web/main.mbt` 为薄适配层，网页调用编译后的真实 MoonBit 模块。

## 独立分装使用

本文件夹可以单独移动或建立仓库，不依赖其他候选项目。浏览器演示已编译，无须安装 MoonBit 即可试用（需要 Python 3）：

```powershell
./start-review.ps1
```

打开 http://127.0.0.1:8777/web/ 。修改和测试源码需安装 MoonBit 与 Node.js，再运行 `./verify.ps1`。本机尚未将 MoonBit 加入 PATH 时，可传入 `-MoonPath`。独立包不捆绑编译器。

仅含本项目源码和构建产物；没有上传仓库或发布包。`DUPLICATION.md`、`evidence/current-validation.json` 和本次分装清单 提供查重、测试和完整性资料。

## 独立仓库工作流

本目录是该项目后续开发的唯一主仓库，旧批次目录及 ZIP 为历史审查快照。没有 Git remote，没有共享构建目录，没有上级 moon.work。

真实 CLI 支持输入参数、文件和标准输入：

```powershell
node tools/cli.mjs --help
node tools/cli.mjs --file sample.txt --json
```

需要安装 MoonBit 后传 `-MoonPath` 或将 moon 加入 PATH；不依赖工作区之外的私有脚本。详见 [TESTING.md](TESTING.md) 和 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 本轮功能升级

增加 PING 到 PONG 的响应接口，修复非法 UTF-16 崩溃。

仍不含 socket/TLS、自动重连、SASL 认证和完整网络客户端；CAP END 与注册时机由调用方控制。

[可执行 API 示例](README.mbt.md)会随测试运行；[功能边界](FEATURES.md)和[测试说明](TESTING.md)用于独立审查。网页与 CLI 展示示例入口，新 API 的完整使用见可执行示例。


新增 MoonBit CAP 302 状态：多行 LS/LIST/ACK 原子更新、能力值、REQ、NAK、NEW/DEL 和资源边界。

规范：[IRCv3 Capability Negotiation](https://ircv3.net/specs/extensions/capability-negotiation.html)。新增 10 组按规范编写的测试；未做真实 IRC 服务器互操作，不能据此宣称完整客户端兼容。
