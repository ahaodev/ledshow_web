import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ledshow_web/localstorage/storage.dart';
import 'package:ledshow_web/models/LedParameters.dart';
import 'package:ledshow_web/models/Resp.dart';
import 'package:ledshow_web/net/http.dart';
import 'package:ledshow_web/provider/WebSocketProvider.dart';
import 'package:ledshow_web/screens/login/login_page.dart';
import 'package:ledshow_web/widget/mytoast.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  final String authCode;
  final String ip;
  final String name;
  final bool enableVAdd;

  String limitsCount;
  WebSocketProvider? webSocketProvider;

  MainScreen(
      this.authCode, this.name, this.limitsCount, this.ip, this.enableVAdd,
      {super.key});

  @override
  State<StatefulWidget> createState() => _DashboardScreen();
}

class _DashboardScreen extends State<MainScreen> {
  String inCount = "0";
  String outCount = "0";
  String existCount = "0";
  String maxCount = "0";
  String version = "1.0.0";
  List<LedParameters> leds = List.empty(growable: true);

  Future auth(String ip, String authCode) async {
    try {
      HttpUtils.setAddress(ip);
      var resp = await HttpUtils.get("/auth/$authCode", "");
      log("auth response: $resp");
      
      int code = resp["code"];
      log("response code: $code");
      
      if (code == SUCCESS) {
        log("code is SUCCESS");
        var data = resp['data'];
        log("data: $data");
        
        if (data != null) {
          log("setting state with data");
          setState(() {
            inCount = data['inCount']?.toString() ?? "0";
            outCount = data['outCount']?.toString() ?? "0";
            existCount = data['existCount']?.toString() ?? "0";
            maxCount = data['limitsCount']?.toString() ?? "0";
          });
          log("state updated: in=$inCount, out=$outCount, exist=$existCount, max=$maxCount");
        } else {
          log("data is null");
        }
      } else {
        log("code is not SUCCESS, code=$code");
      }
    } catch (e) {
      log("error----$e");
      return false;
    }
  }

  void getLedList() async {
    try {
      var resp = await HttpUtils.get("/leds/${widget.authCode}", "");
      int code = resp["code"];
      if (code == SUCCESS) {
        leds.clear();
        setState(() {
          List<dynamic> items = resp['data'];
          for (var item in items) {
            var parameters = LedParameters();
            parameters.name = item["name"];
            parameters.height = item["h"];
            parameters.width = item["w"];
            parameters.x = item["x"];
            parameters.y = item["y"];
            parameters.fontSize = item["fontSize"];
            parameters.ip = item["ip"];
            parameters.port = item["port"];
            leds.add(parameters);
          }
        });
      }
    } catch (e) {
      log("获取LED失败$e");
      FToast()
          .init(context)
          .showToast(child: MyToast(tip: "获取LED失败$e", ok: false));
    }
  }

  void reconnect(String ip) async {
    try {
      var resp = await HttpUtils.get("/recon/$ip", "");
      int code = resp["code"];
      if (code == SUCCESS) {
        setState(() {});
      }
    } catch (e) {
      log("$e");
    }
  }

  @override
  void initState() {
    super.initState();
    HttpUtils.setAddress(widget.ip);
    auth(widget.ip, widget.authCode);
    getLedList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.webSocketProvider = Provider.of<WebSocketProvider>(context);
    widget.webSocketProvider?.initConnect(widget.ip);
    widget.webSocketProvider?.subscribe("home", (id, event, data) {
      log("message id=$id , event=$event, data=$data");
      switch (event) {
        case "LIMIT":
          setState(() {
            maxCount = data;
          });
          break;
        case "LED":
          for (var led in leds) {
            if (led.ip == id) {
              setState(() {
                led.status = data;
              });
            }
          }
          break;
        case "IN":
          setState(() {
            inCount = data;
          });
          break;
        case "OUT":
          setState(() {
            outCount = data;
          });
          break;
        case "EXIST":
          setState(() {
            existCount = data;
          });
          break;
        case "VERSION":
          setState(() {
            version = data;
          });
          break;
      }
    });
  }

  Function wsCall() {
    return (id, event, data) {};
  }

  @override
  void dispose() {
    widget.webSocketProvider?.unsubscribe("home");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log("build");
    // ApiManager.getStream("request");
    Future<int?> _showMaxCountDialog() async {
      TextEditingController _textController = TextEditingController();
      return showDialog<int>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('输入限流值并确认'),
            content: TextFormField(
              controller: _textController,

              keyboardType: TextInputType.number, // 设置输入类型为数字
              decoration: InputDecoration(
                  hoverColor: Theme.of(context).highlightColor,
                  //labelStyle: formTextStyle(context),
                  //hintStyle: formTextStyle(context),
                  border: const OutlineInputBorder(),
                  labelText: '最大限流人数',
                  hintText: '最大限流人数'),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  int? value = int.tryParse(_textController.text);
                  if (value != null) {
                    Navigator.of(context).pop(value); // 返回输入的整数值
                  } else {
                    // 如果输入不是有效的整数，则弹出提示
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('提示'),
                          content: const Text('错误的数值'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('确定'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
                child: const Text('确定'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 关闭对话框
                },
                child: const Text('取消'),
              ),
            ],
          );
        },
      );
    }

    Future<bool?> showConfimDialog() async {
      return showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('提示'),
            content: const Text('确认退出并切换节点?'),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  await RemoveAuth();
                  Navigator.of(context).pop(true); // 用户确认对话框，返回true
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => route == null,
                  );
                },
                child: const Text('确定'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false); // 用户取消对话框，返回false
                },
                child: const Text('取消'),
              ),
            ],
          );
        },
      );
    }

    // 统计数据卡片
    Widget _buildStatCard(String title, String value, IconData icon, Color color) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // 操作按钮
    Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }

    List<Widget> widgets() {
      List<Widget> widgets = List.empty(growable: true);

      // 标题区域
      widgets.add(Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "${widget.name} (${widget.authCode})",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ));
      widgets.add(const SizedBox(height: 16));

      // 节点信息
      widgets.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            "节点: ${widget.ip}",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(width: 16),
          Text(
            "v${version.replaceAll('"', '')}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ));
      widgets.add(const SizedBox(height: 16));

      // 统计数据网格
      widgets.add(LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              SizedBox(
                width: constraints.maxWidth > 400 ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2,
                child: GestureDetector(
                  onTap: () async {
                    var newMaxCount = await _showMaxCountDialog();
                    if (newMaxCount != null) {
                      try {
                        await HttpUtils.get(
                            "/updateMaxCount/${widget.authCode}/$newMaxCount", "");
                        await SaveAuth(
                            "${widget.authCode}|${widget.name}|$newMaxCount|${widget.ip}");
                        widget.limitsCount = "$newMaxCount";
                        setState(() {
                          log("limit count $newMaxCount");
                        });
                      } catch (e) {
                        FToast().init(context).showToast(
                            child: MyToast(tip: "$e", ok: false));
                      }
                    }
                  },
                  child: _buildStatCard("限流人数 ✏️", maxCount, Icons.people_alt, Colors.orange),
                ),
              ),
              SizedBox(
                width: constraints.maxWidth > 400 ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2,
                child: _buildStatCard("今日接待", inCount, Icons.login, Colors.blue),
              ),
              SizedBox(
                width: constraints.maxWidth > 400 ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2,
                child: _buildStatCard("出园人数", outCount, Icons.logout, Colors.purple),
              ),
              SizedBox(
                width: constraints.maxWidth > 400 ? (constraints.maxWidth - 24) / 4 : (constraints.maxWidth - 8) / 2,
                child: _buildStatCard("当前在园", existCount, Icons.groups, Colors.green),
              ),
            ],
          );
        },
      ));
      widgets.add(const SizedBox(height: 20));

      // 操作按钮区域
      widgets.add(Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              _buildActionButton("手动放行10人", Icons.outbond, Colors.teal, () async {
                await upOut10();
                FToast().init(context).showToast(
                    child: const MyToast(tip: "出口放行10人,请观察当前在园", ok: true));
              }),
              if (widget.enableVAdd)
                _buildActionButton("手动入园1人", Icons.emoji_people, Colors.indigo, () async {
                  await upIn1();
                  FToast().init(context).showToast(
                      child: const MyToast(tip: "手动入园1人次,请观察当前在园", ok: true));
                }),
              _buildActionButton("切换节点", Icons.swap_horiz, Colors.grey, () async {
                showConfimDialog();
              }),
            ],
          ),
        ),
      ));
      widgets.add(const SizedBox(height: 24));

      // LED 标题
      if (leds.isNotEmpty) {
        widgets.add(Row(
          children: [
            Icon(Icons.lightbulb, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              "LED 设备",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${leds.length}",
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ));
        widgets.add(const SizedBox(height: 12));

        for (var led in leds) {
          bool isConnected = led.status.contains("连接") || led.status.toLowerCase().contains("connect");
          widgets.add(Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 状态指示灯
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.tv,
                      color: isConnected ? Colors.green : Colors.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          led.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "IP: ${led.ip}",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isConnected ? Colors.green : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              led.status,
                              style: TextStyle(
                                color: isConnected ? Colors.green : Colors.orange,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 重连按钮
                  IconButton(
                    onPressed: () => reconnect(led.ip),
                    icon: const Icon(Icons.refresh),
                    color: Colors.blue,
                    tooltip: "重新连接",
                  ),
                ],
              ),
            ),
          ));
          widgets.add(const SizedBox(height: 8));
        }
      }
      return widgets;
    }

    return Scaffold(
        body: SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: widgets(),
        ),
      ),
    ));
  }

  Future<void> upOut10() async {
    try {
      await HttpUtils.get("/upOut/${widget.authCode}", "");
    } catch (e) {
      log("error:$e");
    }
  }

  Future<void> upIn1() async {
    try {
      await HttpUtils.get("/upIn/${widget.authCode}", "");
    } catch (e) {
      log("error:$e");
    }
  }
}
