import 'dart:async';

import 'package:breez/bloc/account/account_bloc.dart';
import 'package:breez/bloc/account/account_model.dart';
import 'package:breez/bloc/blocs_provider.dart';
import 'package:breez/bloc/invoice/invoice_bloc.dart';
import 'package:breez/services/injector.dart';
import 'package:breez/services/nfc.dart';
import 'package:breez/theme_data.dart' as theme;
import 'package:breez/widgets/back_button.dart' as backBtn;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class PayNearbyComplete extends StatefulWidget {
  PayNearbyComplete();

  @override
  State<StatefulWidget> createState() {
    return PayNearbyCompleteState();
  }
}

class PayNearbyCompleteState extends State<PayNearbyComplete>
    with WidgetsBindingObserver {
  final String _title = "Pay Someone Nearby";
  final String _instructions =
      "To complete the payment,\nplease hold the payee's device close to yours\nas illustrated below:";
  static ServiceInjector _injector = ServiceInjector();
  NFCService _nfc = _injector.nfc;

  InvoiceBloc _invoiceBloc;
  AccountBloc _accountBloc;

  StreamSubscription _blankInvoiceSubscription;
  StreamSubscription _paidInvoicesSubscription;
  StreamSubscription<CompletedPayment> _sentPaymentResultSubscription;

  var _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isInit = false;

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _blankInvoiceSubscription = _nfc.startP2PBeam().listen((blankInvoice) {},
          onError: (err) => _scaffoldKey.currentState.showSnackBar(SnackBar(
              duration: Duration(seconds: 3), content: Text(err.toString()))));
    }
  }

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      _invoiceBloc = AppBlocsProvider.of<InvoiceBloc>(context);
      _accountBloc = AppBlocsProvider.of<AccountBloc>(context);
      startNFCStream();
      registerFulfilledPayments();
      _isInit = true;
    }
    super.didChangeDependencies();
  }

  void startNFCStream() {
    _blankInvoiceSubscription = _nfc.startP2PBeam().listen((blankInvoice) {
      // In the future perhaps show some information about the user we are paying to?
    },
        onError: (err) => _scaffoldKey.currentState.showSnackBar(SnackBar(
            duration: Duration(seconds: 3), content: Text(err.toString()))));
  }

  void registerFulfilledPayments() {
    _paidInvoicesSubscription = _invoiceBloc.paidInvoicesStream.listen((paid) {
      Navigator.of(context).pop('Payment was sent successfuly!');
    },
        onError: (err) => _scaffoldKey.currentState.showSnackBar(SnackBar(
            duration: Duration(seconds: 3),
            content: Text("Failed to send payment: " + err.toString()))));

    _sentPaymentResultSubscription =
        _accountBloc.completedPaymentsStream.listen((fulfilledPayment) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
          duration: Duration(seconds: 3),
          content: Text('Payment was sent successfuly!')));
      Navigator.of(this.context).pop();
    });
  }

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nfc.checkNFCSettings().then((isNfcEnabled) {
      if (!isNfcEnabled) {
        return Timer(Duration(milliseconds: 500), () {
          _showAlertDialog();
        });
      }
    });
  }

  void _showAlertDialog() {
    AlertDialog dialog = AlertDialog(
      content: Text(
          "Breez requires NFC to be enabled in your device in order to pay someone nearby.",
          style: Theme.of(context).dialogTheme.contentTextStyle),
      actions: <Widget>[
        FlatButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL",
                style: Theme.of(context).primaryTextTheme.button)),
        FlatButton(
            onPressed: () {
              _nfc.openSettings();
              Navigator.pop(context);
            },
            child: Text("SETTINGS",
                style: Theme.of(context).primaryTextTheme.button))
      ],
    );
    showDialog(
        useRootNavigator: false, context: context, builder: (_) => dialog);
  }

  @override
  void dispose() {
    _blankInvoiceSubscription.cancel();
    _paidInvoicesSubscription.cancel();
    _sentPaymentResultSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          iconTheme: Theme.of(context).appBarTheme.iconTheme,
          textTheme: Theme.of(context).appBarTheme.textTheme,
          backgroundColor: Theme.of(context).canvasColor,
          leading: backBtn.BackButton(),
          title: Text(
            _title,
            style: Theme.of(context).appBarTheme.textTheme.headline6,
          ),
          elevation: 0.0,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: 48.0, left: 16.0, right: 16.0),
              child: Text(
                _instructions,
                textAlign: TextAlign.center,
                style: theme.textStyle,
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                "src/images/waves-middle.png",
                fit: BoxFit.contain,
                width: double.infinity,
                alignment: Alignment.bottomCenter,
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                "src/images/nfc-p2p-background.png",
                fit: BoxFit.contain,
                width: double.infinity,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
