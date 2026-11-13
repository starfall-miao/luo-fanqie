import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../../shared/widgets/tomato_mark.dart';

/// 一个不带任何权限申请的说明页。
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: '返回',
                          size: 40,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        const TomatoMark(size: 28),
                        const SizedBox(width: 8),
                        Text(
                          '落·番茄',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    PageHeader(
                      eyebrow: '安全与权限',
                      title: '把数据，留在自己手里',
                      subtitle: '默认本地运行；只有你主动接入文件服务器后，才会产生同步网络请求。',
                    ),
                    const SizedBox(height: 20),
                    _SecurityCard(
                      icon: Icons.lock_outline_rounded,
                      title: '数据去向',
                      children: const [
                        _SecurityLine(
                          icon: Icons.check_circle_outline_rounded,
                          text: '任务、标签、计时记录、设置只保存在本机。',
                        ),
                        _SecurityLine(
                          icon: Icons.check_circle_outline_rounded,
                          text: '不接入广告、统计 SDK、崩溃上报或第三方云盘。',
                        ),
                        _SecurityLine(
                          icon: Icons.check_circle_outline_rounded,
                          text: '同步关闭时，应用不会主动访问任何网络地址。',
                        ),
                        _SecurityLine(
                          icon: Icons.check_circle_outline_rounded,
                          text: '同步只连接你在设置中填写的 WebDAV / OpenAlist / FTP 地址。',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SecurityCard(
                      icon: Icons.verified_user_outlined,
                      title: '权限按需申请',
                      children: const [
                        _SecurityLine(
                          icon: Icons.notifications_none_rounded,
                          text: '通知：只在第一次开始专注、且通知开关打开时申请（Android 13+）。拒绝后计时仍可正常使用。',
                        ),
                        _SecurityLine(
                          icon: Icons.alarm_rounded,
                          text: '精确闹钟：不主动弹窗；没有授权时自动使用近似提醒。可在系统设置中为落·番茄单独开启。',
                        ),
                        _SecurityLine(
                          icon: Icons.accessibility_new_rounded,
                          text: '无障碍守护：只在你开启学霸模式并开始专注后工作；只读取当前前台应用包名，不读取屏幕文字、密码或聊天内容。',
                        ),
                        _SecurityLine(
                          icon: Icons.fullscreen_rounded,
                          text: '置顶提醒：离开落·番茄时由无障碍服务绘制全屏提醒，计时结束自动回到应用；可随时点「结束守护」或关闭系统无障碍服务。',
                        ),
                        _SecurityLine(
                          icon: Icons.lock_outline_rounded,
                          text: '锁定任务：可选 Android screen pinning，由系统确认；不会隐藏桌面图标或修改壁纸/启动器。',
                        ),
                        _SecurityLine(
                          icon: Icons.notifications_off_outlined,
                          text: '静音通知：需要系统勿扰访问；专注期间静音，结束恢复，通知不会被读取或删除。',
                        ),
                        _SecurityLine(
                          icon: Icons.query_stats_rounded,
                          text: '应用使用情况：需要 Android 使用情况访问；只在本机汇总前台时长，不上传，也不读取屏幕内容。',
                        ),
                        _SecurityLine(
                          icon: Icons.wifi_off_rounded,
                          text: '网络：Android 的 INTERNET 是安装时普通权限，不会弹窗；只有配置并触发同步后才使用。',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SecurityCard(
                      icon: Icons.block_rounded,
                      title: '不会申请的权限',
                      children: const [
                        _SecurityLine(
                          icon: Icons.close_rounded,
                          text: '位置、相机、麦克风、通讯录、短信、通话记录、读写外部存储。',
                        ),
                        _SecurityLine(
                          icon: Icons.close_rounded,
                          text: '设备管理员、悬浮窗权限、安装未知应用、读取其他应用内容等高风险能力。',
                        ),
                        _SecurityLine(
                          icon: Icons.close_rounded,
                          text: '不会实现阻止其他 App、隐藏桌面图标或防卸载。',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SecurityCard(
                      icon: Icons.dns_outlined,
                      title: '文件服务器与凭据',
                      children: const [
                        _SecurityLine(
                          icon: Icons.https_rounded,
                          text: '优先使用 HTTPS WebDAV / OpenAlist；FTP 是明文协议，如服务器支持请开启 FTPS。',
                        ),
                        _SecurityLine(
                          icon: Icons.key_outlined,
                          text: '服务器密码与地址保存在本机应用私有存储中；应用不会把它们发给任何第三方。',
                        ),
                        _SecurityLine(
                          icon: Icons.warning_amber_rounded,
                          text: '应用沙盒不等于端到端加密；共享设备或已越狱/已 root 的设备上，凭据仍可能被读取。',
                        ),
                        _SecurityLine(
                          icon: Icons.delete_outline_rounded,
                          text: '断开同步只清除本机配置，不删除服务器上的文件；卸载应用会删除本地数据。',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        '完整安全说明见仓库 SECURITY.md',
                        style: TextStyle(fontSize: 10.5, color: surfaces.faint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SecurityLine extends StatelessWidget {
  const _SecurityLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: surfaces.muted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: surfaces.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
