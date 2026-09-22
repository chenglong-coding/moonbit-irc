> 2026-09-22 当前本地版 0.5.0：申报定位为“IRCv3 协商与 TLS/SASL 会话核心”。已更新[现有项目对照](DUPLICATION.md)、[申报草稿](PROPOSAL.md)及[本轮验证](evidence/innovation-review-20260922/results.json)。下面带日期的旧轮次描述保留历史范围；团队已有公开仓库，本次本地修订尚未由本任务推送。

# IRC 协议核心

> 2026-09-21 本地构建修复：命令包 import 已同步到当前 moon.mod 模块名；moon info/check、JS 构建、MoonBit 示例和 Node 引擎示例通过。算法未改，本轮未重跑历史全部行为/性能套件。当前提交指纹见 evidence/module-import-fix.json。

IRC 消息、IRCv3 tags 和受限增量行解析。本地候选版 0.5.0，供比较和代码审查；尚未作为完整竞赛作品提交。

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

已实现 TCP/TLS、CAP、SASL PLAIN；尚无完整昵称/频道状态缓存。

## 来源与实现方式

规格/算法参考：https://modern.ircdocs.horse/。

当前代码是本地新写的 MoonBit 实现，不声称是上游完整移植；未复制上游源代码、词库或测试集。测试输入为本项目新写。MIT 仅适用于本目录原创代码。将来如移植上游文件，需要另行保存其版权声明并核查许可证，不能直接沿用当前说明。

## 审查

先看 `cmd/main/main.mbt` 的实际使用，再看公共 API 与测试文件。联网兼容性、性能数据或官方验收未执行的部分不得从本地单元测试成功推断。

## 下一阶段与明确限制

继续补 SASL 其他机制、昵称/频道状态及 IRCv3 tag key 更完整验证；当前要求 UTF-8，历史服务器的其他编码不在本版范围。

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

尚无 SASL EXTERNAL/SCRAM 与 SASLprep、频道成员/模式缓存、自动重加入和长期多服务端验证；目前仅支持 PLAIN 认证机制。

[可执行 API 示例](README.mbt.md)会随测试运行；[功能边界](FEATURES.md)和[测试说明](TESTING.md)用于独立审查。网页与 CLI 展示示例入口，新 API 的完整使用见可执行示例。


新增 MoonBit CAP 302 状态：多行 LS/LIST/ACK 原子更新、能力值、REQ、NAK、NEW/DEL 和资源边界。

规范：[IRCv3 Capability Negotiation](https://ircv3.net/specs/extensions/capability-negotiation.html)。新增 10 组按规范编写的测试；另已通过 Ergo 2.19.1 本地 TLS/SASL/消息互通；仍不宣称全部 IRC 客户端行为兼容。


0.4.0 新增 MoonBit 注册/协商会话和 Node TCP/TLS 客户端：自动 PONG、CAP 选择与等待确认、注册拒绝、超时、有上限的重连、收发缓冲限制。

## 实际连接

`tools/network-client.mjs` 使用附带的 MoonBit 引擎，Node 24 可直接导入。默认 TLS 且验证证书与主机名；默认不重连，可设置 maxReconnects 和 reconnectDelayMs。每次重连新建 MoonBit Session，重新注册。网络入口不会自动加入频道或发送聊天消息。

```js
import {IrcClient} from './tools/network-client.mjs';
const client = new IrcClient({host:'irc.example.org', nick:'reviewer', capabilities:['server-time'], maxReconnects:2});
client.on('message', line => console.log(line));
client.on('fault', error => console.error(error.message));
await client.connect(); // 在收到 001 后完成
// client.send('JOIN #your-channel'); // 由应用显式发起
// client.close();
```

`node tools/test-network.mjs` 启动本机 TCP/TLS 测试服务器，不连接公网。TLS 测试需要 OpenSSL（Windows 可使用 Git 自带版本或 OPENSSL 环境变量）。11 项网络测试覆盖注册协商、拆包中文、服务端实际收到发送数据、拒绝/超时、重连、非法流和证书校验。TLS 测试密钥临时生成并清理。它们是协议测试服务端，不是第三方 IRC daemon 的互操作证明。

connect 只使用一次；registered 事件在每次注册成功时触发。close 取消重连；不缓存断线时的发送请求。默认注册 15 秒、空闲 120 秒，重连次数覆盖该客户端生命周期，不在成功后清零。单行上限 8194 字节，待发送数据上限 1 MiB。


0.5.0 新增服务器 PASS 与必需 SASL PLAIN 认证：CAP 确认后发送凭证，400 字节分块、等待 903、拒绝匿名降级。Node 认证连接要求 TLS。

## 身份认证

Node 客户端可传 `serverPassword`，以及 `sasl: {username, password, authorizationId}`；后者默认授权身份为空。提供 SASL 凭证后，认证成为注册的必要条件。不支持 SASL/PLAIN、NAK、902/904/905/906/907、认证前 001 都使连接失败。不会自动降级匿名登录。服务器密码在 NICK/USER 前发送，凭证只通过证书验证成功的 TLS 连接发送。

MoonBit API：`Session::new([], plain=Some(SaslPlain::new(username, password)))`，`start(nick,user,realname,server_password=Some(password))`。底层 API 的宿主负责保证受保护传输。用户名和密码按 UTF-8 编码，禁止 NUL 与非法 Unicode，每字段最多 4096 个 UTF-16 单元；未实现 SASLprep。认证数据发送后从会话字段清除，但不承诺 GC 内存安全擦除。重连所需凭证由 Node 配置持有，应用不要记录配置对象。

新增 6 组核心认证测试；网络套件现有 11 项，包含 TLS 上的正确/错误认证、长中文密码分段、PASS 顺序和提前欢迎消息拒绝。

## 第三方服务端互操作

使用 [Ergo 2.19.1](https://github.com/ergochat/ergo/releases/tag/v2.19.1) 官方发行包，Windows ZIP SHA-256 已与官方清单核对：`5397fac56f7110839aac2d8ab436279eb2a00dddfcc07032605b423e85ea40b6`。服务端独立下载，不放入本项目源码包。

```powershell
$env:ERGO_HOME='C:/path/to/ergo-2.19.1-windows-x86_64'
node tools/test-ergo.mjs
```

脚本在临时目录建立数据库和证书，仅监听随机本机端口；创建合成测试账号，检查注册、SASL 903、中文消息、server-time 以及错误密码 904，最后退出服务端并清理临时目录。实际 6 项检查通过，版本和二进制哈希见 `evidence/ergo-interop.json`。这证明该版本上这些路径的互操作，不代表全部 IRCv3 扩展或长期运行已完成验证。
