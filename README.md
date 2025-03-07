# StatusSyn

StatusSyn 是一个 macOS 状态同步工具，它可以实时监控并同步您的应用程序使用状态。
该程序依赖于- [StillAlive 后端](https://github.com/Yao-lin101/StillAlive) - 后端服务

## 功能特点

- 实时监控活动窗口和浏览器标签页
- 支持主流浏览器（Safari、Chrome、Edge 等）的标签页监控
- 自定义服务器配置
- 防抖动机制，避免频繁状态更新
- 开机自启动选项
- 状态栏显示当前应用图标

## 使用方法

1. 首次启动时，点击状态栏图标，选择"配置"进行服务器设置：
   - 输入 Base URL（服务器地址）
   - 输入 Character Key（身份验证密钥）

2. 配置完成后，点击"启用同步"开始同步状态

3. 其他选项：
   - 开机启动：设置应用是否随系统启动
   - 配置：修改服务器设置
   - 退出：关闭应用

## 状态更新规则

- 普通应用：显示应用名称
- 浏览器：显示"浏览器名称 + 当前标签页标题"
- 状态更新采用 3 秒防抖动机制，避免频繁切换时的大量请求

## 网络请求格式

```json
{
    "type": "mac",
    "data": {
        "mac": "应用名称/浏览器状态"
    }
}
```

## 系统要求

- macOS 11.0 或更高版本
- 需要网络连接
- 如需浏览器标签监控，需要授予辅助功能权限

## 隐私说明

- 应用仅收集当前窗口标题和浏览器标签信息
- 所有数据仅发送至用户配置的服务器
- 不会收集或存储其他个人信息

## 注意事项

1. 首次使用需要完成服务器配置
2. 浏览器标签监控可能需要系统权限
3. 确保服务器地址可访问且配置正确 