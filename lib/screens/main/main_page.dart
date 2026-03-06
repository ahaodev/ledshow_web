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

    List<Widget> widgets() {
      List<Widget> widgets = List.empty(growable: true);
      var infoCard = Card(
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            constraints: const BoxConstraints(minWidth: double.infinity),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text("限流节点：${widget.ip}",
                    style: Theme.of(context).textTheme.titleMedium),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "限流：${maxCount}",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                        onPressed: () async {
                          var maxCount = await _showMaxCountDialog();
                          if (maxCount != null) {
                            try {
                              await HttpUtils.get(
                                  "/updateMaxCount/${widget.authCode}/$maxCount",
                                  "");
                              await SaveAuth(
                                  "${widget.authCode}|${widget.name}|$maxCount|${widget.ip}");
                              widget.limitsCount = "$maxCount";
                              setState(() {
                                log("limit count ${maxCount}");
                              });
                            } catch (e) {
                              FToast().init(context).showToast(
                                  child: MyToast(tip: "$e", ok: false));
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blue,
                        ),
                        label: const Text(
                          "",
                          style: TextStyle(color: Colors.blue),
                        )),
                  ],
                ),
                Text(
                  "今日接待：${inCount}",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  "出园人数：${outCount}",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  "当前在园：${existCount}",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await upOut10();
                        FToast().init(context).showToast(
                            child: const MyToast(
                                tip: "出口放行10人,请观察当前在园", ok: true));
                      },
                      icon: const Icon(
                        Icons.outbond,
                        color: Colors.blue,
                      ),
                      label: const Text(
                        "手动放行 10人",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                if (widget.enableVAdd)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          await upIn1();
                          FToast().init(context).showToast(
                              child: const MyToast(
                                  tip: "手动入园1人次,请观察当前在园", ok: true));
                        },
                        icon: const Icon(
                          Icons.emoji_people,
                          color: Colors.blue,
                        ),
                        label: const Text(
                          "手动入园   1人",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                        onPressed: () async {
                          showConfimDialog();
                        },
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.blue,
                        ),
                        label: const Text(
                          "切换节点",
                          style: TextStyle(color: Colors.blue),
                        )),
                  ],
                ),
                Text("v${version.replaceAll('"', '')}")
              ],
            ),
          ),
        ),
      );
      widgets.add(Text(
        "${widget.name}(${widget.authCode})",
        style: Theme.of(context).textTheme.titleLarge,
      ));
      widgets.add(const SizedBox(height: 8));
      widgets.add(infoCard);
      widgets.add(const SizedBox(height: 16));
      widgets.add(Text(
        "LED",
        style: Theme.of(context).textTheme.titleLarge,
      ));
      if (leds.isNotEmpty) {
        for (var led in leds) {
          widgets.add(Card(
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                constraints: const BoxConstraints(minWidth: double.infinity),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "点位：${led.name}",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "IP：${led.ip}",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        TextButton.icon(
                            onPressed: () {
                              reconnect(led.ip);
                            },
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.blue,
                            ),
                            label: const Text(
                              "重连",
                              style: TextStyle(color: Colors.blue),
                            )),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "状态：",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          led.status,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.apply(color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ));
          widgets.add(const SizedBox(height: 8));
        }
      }
      return widgets; // all widget added now retrun the list here
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
