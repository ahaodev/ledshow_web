import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ledshow_web/config.dart';
import 'package:ledshow_web/localstorage/storage.dart';
import 'package:ledshow_web/models/Resp.dart';
import 'package:ledshow_web/net/http.dart';
import 'package:ledshow_web/utils/StringUtils.dart';
import 'package:ledshow_web/widget/mytoast.dart';

import '../main/main_page.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginScreen> {
  String ip = "127.0.0.1";
  String authCode = "";
  String name = "";
  int limit = 0;
  String version = "";
  var enableVAdd = false;

  @override
  void initState() {
    super.initState();
    getConfig();
  }

  @override
  Widget build(BuildContext context) {
    var ipFormField = TextFormField(
      onChanged: (value) {
        ip = value!;
      },
      decoration: InputDecoration(
          hoverColor: Theme.of(context).highlightColor,
          //labelStyle: formTextStyle(context),
          //hintStyle: formTextStyle(context),
          border: const OutlineInputBorder(),
          labelText: '限流节点网关IP地址',
          hintText: '限流节点网关IP地址'),
    );

    var textFormField = TextFormField(
      onChanged: (value) {
        authCode = value!;
      },
      decoration: InputDecoration(
          hoverColor: Theme.of(context).highlightColor,
          //labelStyle: formTextStyle(context),
          //hintStyle: formTextStyle(context),
          border: const OutlineInputBorder(),
          labelText: '景点编号',
          hintText: '请输入景点编号'),
    );
    var card = Card(
      elevation: 5,
      child: Container(
        constraints: const BoxConstraints(
            minWidth: 500.0,
            minHeight: 400.0,
            maxWidth: 600.0,
            maxHeight: 500.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "限流服务",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Padding(
              padding: const EdgeInsets.only(
                  left: 100.0, right: 100.0, top: 32.0, bottom: 16.0),
              child: ipFormField,
            ),
            Padding(
              padding: const EdgeInsets.only(
                  left: 100.0, right: 100.0, top: 8.0, bottom: 32.0),
              child: textFormField,
            ),
            ElevatedButton(
                onPressed: () async {
                  if (!isValidIPAddress(ip)) {
                    FToast().init(context).showToast(
                        child: const MyToast(tip: "限流网关IP填写错误！", ok: false));
                    return;
                  }
                  if (authCode == "") {
                    FToast().init(context).showToast(
                        child: const MyToast(tip: "编号为空", ok: false));
                    return;
                  }
                  var isHanzi = RegExp(r'[\u4e00-\u9fa5]').hasMatch(authCode);
                  if (isHanzi) {
                    FToast().init(context).showToast(
                        child:
                            const MyToast(tip: "输入错误 编号由a~y,0~9组成", ok: false));
                    return;
                  }
                  var ok = await auth(ip, authCode);
                  if (ok) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              MainScreen(authCode, name, "$limit", ip,enableVAdd)),
                      (route) => route == null,
                    );
                  }
                },
                child: const Text("进入")),
          ],
        ),
      ),
    );
    return Scaffold(
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
        children: [
          card,
          Padding(
            padding:
                const EdgeInsets.only(left: 100.0, right: 100.0, top: 64.0),
            child: Text("Version-$version"),
          ),
          const Padding(
            padding:
            EdgeInsets.only(left: 100.0, right: 100.0, top: 0.0),
            child: Text("Copyright © UChi. All Rights Reserved."),
          ),
        ],
      )),
    );
  }

  void getConfig() async {
    var config = await loadConfig();
    version = config["version"];
    setState(() {});
  }

  Future<bool> auth(String ip, String authCode) async {
    try {
      HttpUtils.setAddress(ip);
      var resp = await HttpUtils.get("/auth/$authCode", "");
      log(resp.toString());
      int code = resp["code"] as int;
      if (code != null && code == SUCCESS) {
        name = resp["data"]["name"];
        limit = resp["data"]["limitsCount"];
        enableVAdd =resp["data"]["enableVAdd"];
        await SaveAuth("$authCode|$name|$limit|$ip|$enableVAdd");
        return true;
      } else {
        FToast()
            .init(context)
            .showToast(child: MyToast(tip: "${resp["msg"]}", ok: false));
        return false;
      }
    } catch (e) {
      log("error----$e");
      FToast().init(context).showToast(child: MyToast(tip: "${e}", ok: false));
      return false;
    }
  }
}
