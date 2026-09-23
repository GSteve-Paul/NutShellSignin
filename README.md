# NutShellSignin · 果壳签到

Flutter 原生客户端，支持 Windows、Linux、macOS、iOS、Android。实现 UCAS 登录、当天课表与逐课签到，直接通过 HTTPS 访问上游，不需要 Go 代理。

## 使用

1. 输入学号和密码，选择是否「记住账号密码」，点击登录。
2. 勾选后，仅在登录成功时将账号密码存入系统安全存储。下次启动自动填入，**不会自动登录或自动签到**。
3. 课表按北京时间排列，开课前 30 分钟至下课可提交签到。已签到记录不能重复提交。
4. 点击签到，核对课程和经纬度后提交。可输入地点名称并点击「保存地点」；以后从「已保存地点」选择，即可回填经纬度。选中后可修改名称或坐标并「更新地点」，也可新建或删除地点。坐标初始值沿用 UCASCoureLogin 的校区配置，**不是设备 GPS 定位**，可以修改。
5. 签到成功响应后刷新课表，只有目标课次的 `signStatus=1` 才提示已确认成功。超时不自动重试，请先刷新确认。
6. 登录后可从右上角菜单进入「管理已保存地点」，查看每个地点的名称和经纬度，新增、修改或确认删除地点。管理页面与签到窗口共用同一份持久化数据，无需有可签到课程也能管理。菜单还可退出；「退出并删除保存的账号密码」同时清除保存的登录凭据。登录页关闭「记住账号密码」也立即删除保存的凭据。

## 开发与构建

工具版本：Flutter **3.44.1** / Dart **3.12.1**。提交 `pubspec.lock` 固定依赖，五个平台的原生工程已纳入仓库。先运行：

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d linux # 按当前设备替换
```

| 目标 | 构建宿主与依赖 | 构建命令 |
| --- | --- | --- |
| Linux | Linux、clang、CMake、Ninja、GTK 3、libsecret 开发包 | `flutter build linux --release` |
| Windows | Windows、Visual Studio 的 Desktop development with C++，包含 ATL | `flutter build windows --release` |
| macOS | macOS、Xcode 与其命令行工具 | `flutter build macos --release` |
| iOS | macOS、Xcode；真机分发需要 Apple 签名配置 | `flutter build ios --release --no-codesign` |
| Android | Android SDK、JDK 17 | `flutter build apk --release` |

Linux Debian/Ubuntu 构建依赖：

```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev
```

Fedora：

```bash
sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel libsecret-devel
```

如果构建提示 `PkgConfig::LIBSECRET` 引用了不存在的目录，先用 `pkg-config --cflags --libs libsecret-1` 确认系统依赖正常，再清除旧的 Linux CMake 缓存并重建：

```bash
rm -rf build/linux
flutter build linux --release
```

此命令只清理生成的 Linux 构建文件。`flutter run` 默认运行 Debug；运行 Release 使用 `flutter run -d linux --release`。

Linux 运行环境还需要 `libsecret` 与已解锁的 Secret Service（如 GNOME Keyring 或支持该服务的 KWallet）。如果密钥环不可用，界面会提示，仍可手动登录；不会降级为明文存储。

`.github/workflows/ci.yml` 配置静态检查、测试以及五个平台的构建任务。iOS CI 产物未签名；Android 当前沿用 Flutter 模板的 debug key 进行开发构建，即使使用 `--release` 也不是正式发布签名。正式分发前请配置自己的签名与应用标识；不要提交私钥、keystore 或 `key.properties`。桌面分发应保留完整 bundle，macOS/iOS 分发还需对应的签名与公证/打包步骤。

## 代码结构

```text
lib/
  main.dart                   依赖装配和生命周期
  app.dart                    主题与登录/课表页面切换
  core/                       统一异常、北京时间转换
  domain/models.dart          Credentials、UserSession、Course、SignLocation
  data/iclass_api.dart         HTTP 表单、解析、超时、服务端校时
  data/credential_store.dart   登录凭据安全存储适配器
  data/location_store.dart     已命名地点的独立持久化存储
  application/                应用状态、登录和签到业务流程
  presentation/               页面与可复用界面组件
```

依赖通过构造函数注入。界面不接触 HTTP 与存储实现；测试用模拟网关和存储，无需真实账号，不对真实课程发起签到。每次只允许一个签到请求，退出时清除内存会话；只有用户显式登录才建立新会话。

## API 对接

共同前缀：`https://iclass.ucas.edu.cn:8181`，均使用 `POST`、`application/x-www-form-urlencoded`，请求头携带 `sessionId`。

| API | 请求字段 | 响应依赖 |
| --- | --- | --- |
| `/app/user/login.action` | `phone`、`password`、`userLevel=1`、`verificationType=1`、`verificationUrl` | `result.id`、`result.sessionId`、`result.realName` |
| `/app/course/get_stu_course_sched.action` | `id`、`dateStr=YYYYMMDD` | `result[].uuid`、课程名称/教师/教室/起止时间、`signStatus`；响应头 `Date` |
| `/app/course/stu_scan_sign.action` | URL：`timeTableId`、`timestamp`；表单：`id`、`longitude`、`latitude` | `STATUS`，之后查询课表确认 `signStatus` |

`timeTableId` 优先取 `uuid`，兼容回退 `timeTableId / id / UUID / ID`。`timestamp` 为毫秒 Unix 时间，使用最近响应的 `Date` 与请求往返中点估算偏差，再减 1 秒。时间窗口按同一服务端时钟判断，设备位于其他时区也按北京时间获取当天课表。

当前确认的业务成功码为 `STATUS=0`。其他或缺失的 `STATUS` 一律显示失败，不猜测未记录的状态码含义。HTTP 401/403 清除内存会话并要求重新登录；HTTP 200 携带业务错误时显示错误，可手动退出重登。缺少上游 `sessionId` 不会回退成已登录。

登录的初始 `sessionId` 与 `verificationUrl` 来自参考仓库。初始值可在构建时通过 `--dart-define=ICLASS_BOOTSTRAP_SESSION=...` 覆盖。`verificationUrl` 是提交给上游的原样字段，本客户端不直接访问这个 HTTP 地址。上游协议无公开完整文档，业务状态和签到窗口以实际服务返回为准。

## 凭据安全

使用 `flutter_secure_storage`，账号和密码作为一条记录一起保存，便于一致地读取和删除：

- Android：系统 Keystore 保护加密密钥；关闭自动备份，并排除云备份和设备迁移中的应用数据。
- iOS：Keychain，仅设备解锁时可读取，不迁移到其他设备。
- macOS：系统登录 Keychain，使用 `usesDataProtectionKeychain: false`，无需跨应用 Keychain Sharing。
- Windows：插件通过 Windows DPAPI 加密存储。
- Linux：libsecret / Secret Service，由桌面密钥环保护。

不持久化上游会话、课表或密码到普通配置文件，不记录请求体和原始响应，不把异常中的凭据输出到日志。使用默认 TLS 证书校验，不接受无效证书，不向重定向目标转发凭据。安全存储读取、写入或删除失败时明确提示；删除失败不会显示为已删除。自动填充意味着密码会短暂存在应用内存中，系统安全存储主要保护静态数据。

## 测试

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --coverage
# 在有安全存储服务的真实平台测试插件读写，不需要 UCAS 账号：
flutter test integration_test/secure_storage_test.dart -d linux
```

测试覆盖请求字段与编码、毫秒时间戳校准、非北京时间设备的日期边界、业务错误与超时、凭据加载与删除失败、签到防重入和刷新确认，以及手机尺寸下的完整界面操作。原生存储集成测试使用独立临时 key，不读写正式账号记录。

参考：[Flutter 平台支持](https://docs.flutter.dev/platform-integration)、[flutter_secure_storage 配置](https://pub.dev/packages/flutter_secure_storage)。

## 本次构建验证（2026-09-19）

- `flutter analyze`：通过。
- `flutter test`：28 项测试通过；Linux 原生安全存储集成测试另有 1 项通过。
- Linux x64 Release：已构建，当前机器运行库依赖齐全。
- Android Release APK：已构建，APK 完整性与 v2 签名校验通过；包含 arm64-v8a、armeabi-v7a、x86_64，最低 Android API 24。当前使用开发签名。
- Windows、macOS、iOS：原生工程和 CI 构建任务已配置，尚未在对应宿主上实际验证；CI 尚未执行。

整理后的本地产物位于 `build/releases/`：`NutShellSignin-linux-x64.tar.gz`、`NutShellSignin-android.apk` 和 `SHA256SUMS`。Linux 压缩包需完整解压，在解压目录运行 `./nutshell_signin`。构建产物不纳入 Git。

Android APK 是本次 SDK 清理前成功生成的产物，清理后完成了完整性和签名验证，没有重新安装 SDK 或重新编译 Android。后续重建前需确保 `android/local.properties` 的 `sdk.dir` 指向实际安装的 SDK；目录为空时不能构建。原生联网登录、真实课程签到以及 Windows/macOS/iOS 的安全存储仍需在相应环境中验收。


## 已保存地点（2026-09-23）

地点名称和经纬度使用系统安全存储持久化，重启后可继续选择。地点在本设备内共享，与账号密码分开存储；退出登录或删除账号密码不会删除地点。名称不能为空、最长 40 个字符且不可重名；经纬度沿用签到范围校验。保存或删除失败会提示，保留上一次成功保存的数据。读取失败时禁用保存，防止覆盖未读取的地点，仍可手动输入坐标签到。

本次功能更新后已有的 `build/releases/` 安装包仍为 2026-09-19 版本，需重新构建才包含地点保存功能。
