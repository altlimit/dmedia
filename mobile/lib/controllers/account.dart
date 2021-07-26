import 'package:dmedia/controllers/home.dart';
import 'package:get/get.dart';
import 'package:dmedia/model.dart';

class AccountController extends GetxController {
  final account = Account().obs;
  bool isAdd = false;
  Account? currentAccount;
  bool isActive = false;
  final code = ''.obs;
  final errors = {}.obs;
  final isCreate = false.obs;
  int? internalId;
  late bool isFirstAccount = false;

  @override
  void onInit() {
    super.onInit();
    isFirstAccount = Util.getActiveAccountId() == 0;
    internalId = Get.arguments != null ? Get.arguments : null;
    if (internalId != null) {
      var a = Util.getAccount(internalId!);
      if (a != null) {
        account(a);
        isActive = Util.getActiveAccountId() == internalId;
        currentAccount = Account.fromJson(account.toJson());
      }
    } else {
      isAdd = true;
      if (!isRelease) account.value.serverUrl = 'http://192.168.1.70:5454';
    }
  }

  bool get isValidAccount {
    return account.value.serverUrl.length > 0 &&
        account.value.username.length > 0 &&
        account.value.password.length > 0;
  }

  onSaveAccountTap() async {
    var doneLoading = Util.showLoading(Get.context!);
    errors.clear();
    // test connections
    var client = Client(account());
    Map<String, dynamic>? result;
    if (isCreate.value)
      result = await client.request('/api/users?code=' + code.value, data: {
        'username': account.value.username,
        'password': account.value.password,
        'active': true
      });
    else if (isAdd)
      result = await client.request('/api/auth');
    else // is update
    {
      client = Client(currentAccount!);
      result = await client.request('/api/users/' + account.value.id.toString(),
          data: {
            'username': account.value.username,
            'password': account.value.password,
            'admin': account.value.admin,
            'active': true
          },
          method: 'PUT');
    }
    doneLoading();
    var err = client.checkError(result);
    if (err != null) {
      errors.clear();
      errors.addAll(err);
    } else if (!(result!['active'] as bool)) {
      errors['message'] = 'inactive account';
    }
    if (errors.length > 0) return;

    account.update((val) {
      val!.admin = result!['admin'] as bool;
      val.id = result['id'];
    });
    var newActiveId = Util.saveAccount(account(), internalId: internalId);
    if (isAdd) {
      Util.setActiveAccountId(newActiveId);
      if (!isFirstAccount) await Get.find<HomeController>().onPullRefresh();
    }
    if (isFirstAccount)
      Get.offAndToNamed('/home');
    else
      Get.back();
  }

  onSwitchAccountTap() async {
    Util.setActiveAccountId(internalId!);
    await Get.find<HomeController>().onPullRefresh();
    Get.back();
  }

  onDeleteAccountTap() {
    Util.confirmDialog(Get.context!, () {
      Util.delAccount(internalId!);
      Util.delAccountSettings(internalId!);
      Get.back();
    });
  }
}
