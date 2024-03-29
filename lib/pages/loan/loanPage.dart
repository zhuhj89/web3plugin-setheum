import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_svg/svg.dart';
import 'package:liquid_progress_indicator/liquid_progress_indicator.dart';
import 'package:web3plugin_setheum/api/earn/types/incentivesData.dart';
import 'package:web3plugin_setheum/api/types/loanType.dart';
import 'package:web3plugin_setheum/common/constants/index.dart';
import 'package:web3plugin_setheum/pages/loan/loanCreatePage.dart';
import 'package:web3plugin_setheum/pages/loan/loanDepositPage.dart';
import 'package:web3plugin_setheum/pages/loan/loanDetailPage.dart';
import 'package:web3plugin_setheum/pages/loan/loanHistoryPage.dart';
import 'package:web3plugin_setheum/web3plugin_setheum.dart';
import 'package:web3plugin_setheum/utils/format.dart';
import 'package:web3plugin_setheum/utils/i18n/index.dart';
import 'package:web3plugin_setheum/utils/uiUtils.dart';
import 'package:web3wallet_sdk/storage/keyring.dart';
import 'package:web3wallet_sdk/storage/types/keyPairData.dart';
import 'package:web3wallet_sdk/utils/i18n.dart';
import 'package:web3wallet_ui/components/MainTabBar.dart';
import 'package:web3wallet_ui/components/addressIcon.dart';
import 'package:web3wallet_ui/components/infoItem.dart';
import 'package:web3wallet_ui/components/listTail.dart';
import 'package:web3wallet_ui/components/outlinedButtonSmall.dart';
import 'package:web3wallet_ui/components/roundedButton.dart';
import 'package:web3wallet_ui/components/roundedCard.dart';
import 'package:web3wallet_ui/components/tapTooltip.dart';
import 'package:web3wallet_ui/components/tokenIcon.dart';
import 'package:web3wallet_ui/components/txButton.dart';
import 'package:web3wallet_ui/pages/txConfirmPage.dart';
import 'package:web3wallet_ui/utils/format.dart';

class LoanPage extends StatefulWidget {
  LoanPage(this.plugin, this.keyring);
  final PluginSetheum plugin;
  final Keyring keyring;

  static const String route = '/karura/loan';

  @override
  _LoanPageState createState() => _LoanPageState();
}

class _LoanPageState extends State<LoanPage> {
  int _tab = 0;

  Future<void> _fetchData() async {
    widget.plugin.service.gov.updateBestNumber();
    await widget.plugin.service.loan
        .queryLoanTypes(widget.keyring.current.address);

    final priceQueryTokens =
        widget.plugin.store.loan.loanTypes.map((e) => e.token).toList();
    priceQueryTokens.add(widget.plugin.networkState.tokenSymbol[0]);
    widget.plugin.service.assets.queryMarketPrices(priceQueryTokens);

    if (mounted) {
      widget.plugin.service.loan
          .subscribeAccountLoans(widget.keyring.current.address);
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // todo: fix this after new acala online
      final bool enabled = widget.plugin.basic.name == 'acala'
          ? ModalRoute.of(context).settings.arguments
          : true;
      if (enabled) {
        _fetchData();
      } else {
        widget.plugin.store.loan.setLoansLoading(false);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    widget.plugin.service.loan.unsubscribeAccountLoans();
  }

  @override
  Widget build(BuildContext context) {
    final dic = I18n.of(context).getDic(i18n_full_dic_karura, 'acala');

    final stableCoinDecimals = widget.plugin.networkState.tokenDecimals[
        widget.plugin.networkState.tokenSymbol.indexOf(karura_stable_coin)];
    final incentiveTokenSymbol = widget.plugin.networkState.tokenSymbol[0];
    return Observer(
      builder: (_) {
        final loans = widget.plugin.store.loan.loans.values.toList();
        loans.retainWhere((loan) =>
            loan.debits > BigInt.zero || loan.collaterals > BigInt.zero);

        final isDataLoading =
            widget.plugin.store.loan.loansLoading && loans.length == 0;

        final incentiveTokenOptions =
            widget.plugin.store.loan.loanTypes.map((e) => e.token).toList();
        if (widget.plugin.store.earn.incentives.loans != null) {
          incentiveTokenOptions.retainWhere((e) {
            final incentive = widget.plugin.store.earn.incentives.loans[e];
            return incentive != null && (incentive[0].amount ?? 0) > 0;
          });
        }

        return Scaffold(
          backgroundColor: Theme.of(context).cardColor,
          appBar: AppBar(
            title: Text(dic['loan.title.KSM']),
            centerTitle: true,
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.history, color: Theme.of(context).cardColor),
                onPressed: () =>
                    Navigator.of(context).pushNamed(LoanHistoryPage.route),
              )
            ],
          ),
          body: SafeArea(
            child: AccountCardLayout(
                widget.keyring.current,
                Column(
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: MainTabBar(
                        fontSize: 20,
                        lineWidth: 6,
                        tabs: [dic['loan.my'], dic['loan.incentive']],
                        activeTab: _tab,
                        onTap: (i) {
                          setState(() {
                            _tab = i;
                          });
                        },
                      ),
                    ),
                    isDataLoading
                        ? Container(
                            height: MediaQuery.of(context).size.width / 2,
                            child: CupertinoActivityIndicator(),
                          )
                        : Expanded(
                            child: _tab == 0
                                ? loans.length > 0
                                    ? ListView(
                                        padding: EdgeInsets.all(16),
                                        children: loans.map((loan) {
                                          final tokenDecimals = widget.plugin
                                                  .networkState.tokenDecimals[
                                              widget.plugin.networkState
                                                  .tokenSymbol
                                                  .indexOf(loan.token)];
                                          return LoanOverviewCard(
                                            loan,
                                            karura_stable_coin,
                                            stableCoinDecimals,
                                            tokenDecimals,
                                            widget.plugin.tokenIcons,
                                            widget.plugin.store.assets.prices,
                                          );
                                        }).toList(),
                                      )
                                    : RoundedCard(
                                        margin: EdgeInsets.all(16),
                                        padding:
                                            EdgeInsets.fromLTRB(80, 24, 80, 24),
                                        child: SvgPicture.asset(
                                            'packages/web3plugin_setheum/assets/images/loan-start.svg',
                                            color:
                                                Theme.of(context).primaryColor),
                                      )
                                : CollateralIncentiveList(
                                    plugin: widget.plugin,
                                    loans: widget.plugin.store.loan.loans,
                                    tokenIcons: widget.plugin.tokenIcons,
                                    totalCDPs:
                                        widget.plugin.store.loan.totalCDPs,
                                    incentives: widget
                                        .plugin.store.earn.incentives.loans,
                                    rewards: widget
                                        .plugin.store.loan.collateralRewardsV2,
                                    marketPrices:
                                        widget.plugin.store.assets.marketPrices,
                                    collateralDecimals: stableCoinDecimals,
                                    incentiveTokenSymbol: incentiveTokenSymbol,
                                  ),
                          ),
                    Visibility(
                        visible: _tab == 0 &&
                            !isDataLoading &&
                            loans.length <
                                widget.plugin.store.loan.loanTypes.length,
                        child: Container(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: RoundedButton(
                            text: '+ ${dic['loan.create']}',
                            onPressed: () {
                              Navigator.of(context)
                                  .pushNamed(LoanCreatePage.route);
                            },
                          ),
                        )),
                  ],
                )),
          ),
        );
      },
    );
  }
}

class LoanOverviewCard extends StatelessWidget {
  LoanOverviewCard(
    this.loan,
    this.stableCoinSymbol,
    this.stableCoinDecimals,
    this.collateralDecimals,
    this.tokenIcons,
    this.prices,
  );
  final LoanData loan;
  final String stableCoinSymbol;
  final int stableCoinDecimals;
  final int collateralDecimals;
  final Map<String, Widget> tokenIcons;
  final Map<String, BigInt> prices;

  final colorSafe = Color(0xFFB9F6CA);
  final colorWarn = Color(0xFFFFD180);
  final colorDanger = Color(0xFFFF8A80);

  @override
  Widget build(BuildContext context) {
    final dic = I18n.of(context).getDic(i18n_full_dic_karura, 'acala');

    final requiredCollateralRatio =
        double.parse(Fmt.token(loan.type.requiredCollateralRatio, 18));
    final borrowedRatio = 1 / loan.collateralRatio;

    final collateralValue =
        Fmt.bigIntToDouble(prices[loan.token], acala_price_decimals) *
            Fmt.bigIntToDouble(loan.collaterals, collateralDecimals);

    return GestureDetector(
      child: Stack(children: [
        RoundedCard(
          margin: EdgeInsets.only(bottom: 16),
          child: Container(
            width: double.infinity,
            height: 176,
            child: LiquidLinearProgressIndicator(
              value: borrowedRatio,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation(
                  loan.collateralRatio > requiredCollateralRatio
                      ? loan.collateralRatio > requiredCollateralRatio + 0.2
                          ? colorSafe
                          : colorWarn
                      : colorDanger),
              borderRadius: 16,
              direction: Axis.vertical,
            ),
          ),
        ),
        Container(
          color: Colors.transparent,
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 8),
                child: Text(
                    '${dic['loan.collateral']}(${PluginFmt.tokenView(loan.token)})'),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                    margin: EdgeInsets.only(right: 8),
                    child: TokenIcon(loan.token, tokenIcons)),
                Text(
                    Fmt.priceFloorBigInt(loan.collaterals, collateralDecimals,
                        lengthMax: 4),
                    style: TextStyle(
                      fontSize: 26,
                      letterSpacing: -0.8,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    )),
                Container(
                  margin: EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    '≈ \$${Fmt.priceFloor(collateralValue)}',
                    style: TextStyle(
                        letterSpacing: -0.8,
                        color: Theme.of(context).disabledColor),
                  ),
                ),
              ]),
              Row(children: [
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        margin: EdgeInsets.only(top: 24, bottom: 8),
                        child: Text(dic['loan.borrowed'] +
                            '(${PluginFmt.tokenView(stableCoinSymbol)})')),
                    Text(
                      Fmt.priceCeilBigInt(loan.debits, stableCoinDecimals),
                      style: Theme.of(context).textTheme.headline4,
                    )
                  ],
                )),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        margin: EdgeInsets.only(top: 24, bottom: 8),
                        child: Text(dic['loan.ratio'])),
                    Text(
                      Fmt.ratio(loan.collateralRatio),
                      style: Theme.of(context).textTheme.headline4,
                    )
                  ],
                )),
              ])
            ],
          ),
        ),
      ]),
      onTap: () => Navigator.of(context).pushNamed(
        LoanDetailPage.route,
        arguments: loan.token,
      ),
    );
  }
}

class AccountCard extends StatelessWidget {
  AccountCard(this.account);
  final KeyPairData account;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16.0,
            spreadRadius: 4.0,
            offset: Offset(2.0, 2.0),
          )
        ],
      ),
      child: ListTile(
        dense: true,
        leading: AddressIcon(account.address, svg: account.icon, size: 36),
        title: Text(account.name.toUpperCase()),
        subtitle: Text(Fmt.address(account.address)),
      ),
    );
  }
}

class AccountCardLayout extends StatelessWidget {
  AccountCardLayout(this.account, this.child);
  final KeyPairData account;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        margin: EdgeInsets.only(top: 64),
        child: child,
      ),
      AccountCard(account),
    ]);
  }
}

class CollateralIncentiveList extends StatelessWidget {
  CollateralIncentiveList({
    this.plugin,
    this.loans,
    this.incentives,
    this.rewards,
    this.totalCDPs,
    this.tokenIcons,
    this.marketPrices,
    this.collateralDecimals,
    this.incentiveTokenSymbol,
  });

  final PluginSetheum plugin;
  final Map<String, LoanData> loans;
  final Map<String, List<IncentiveItemData>> incentives;
  final Map<String, CollateralRewardDataV2> rewards;
  final Map<String, TotalCDPData> totalCDPs;
  final Map<String, Widget> tokenIcons;
  final Map<String, double> marketPrices;
  final int collateralDecimals;
  final String incentiveTokenSymbol;

  Future<void> _onClaimReward(
      BuildContext context, String token, String rewardView) async {
    try {
      if (plugin.store.setting.liveModules['earn']['actionsDisabled']
              [action_earn_claim] ??
          false) {
        UIUtils.showInvalidActionAlert(context, action_earn_claim);
        return;
      }
    } catch (err) {
      // ignore
    }

    final dic = I18n.of(context).getDic(i18n_full_dic_karura, 'acala');
    final pool = {
      'Loans': {'Token': token}
    };
    final params = TxConfirmParams(
      module: 'incentives',
      call: 'claimRewards',
      txTitle: dic['earn.claim'],
      txDisplay: {'pool': pool, 'amount': '$rewardView $incentiveTokenSymbol'},
      params: [pool],
    );
    Navigator.of(context).pushNamed(TxConfirmPage.route, arguments: params);
  }

  Future<void> _activateRewards(BuildContext context, String token) async {
    try {
      if (plugin.store.setting.liveModules['loan']['actionsDisabled']
              [action_loan_adjust] ??
          false) {
        UIUtils.showInvalidActionAlert(context, action_loan_adjust);
        return;
      }
    } catch (err) {
      // ignore
    }
    final dic = I18n.of(context).getDic(i18n_full_dic_karura, 'acala');
    final params = TxConfirmParams(
      module: 'honzon',
      call: 'adjustLoan',
      txTitle: dic['loan.activate'],
      txDisplay: {'collateral': token},
      params: [
        {'token': token},
        0,
        0
      ],
    );
    Navigator.of(context).pushNamed(TxConfirmPage.route, arguments: params);
  }

  @override
  Widget build(BuildContext context) {
    final dic = I18n.of(context).getDic(i18n_full_dic_karura, 'acala');
    final List<String> tokensAll = incentives.keys.toList();
    tokensAll.addAll(rewards.keys.toList());
    final tokens = tokensAll.toSet().toList();
    // tokens.retainWhere((e) =>
    //     incentives[e] != null ||
    //     (rewards[e]?.reward != null && rewards[e].reward.length > 0));
    tokens.removeWhere((e) => e == 'KSM');

    if (tokens.length == 0) {
      return ListTail(isEmpty: true, isLoading: false);
    }
    return ListView.builder(
        padding: EdgeInsets.only(bottom: 32),
        itemCount: tokens.length,
        itemBuilder: (_, i) {
          final token = tokens[i];
          final collateralValue = Fmt.bigIntToDouble(
              loans[token]?.collateralInUSD, collateralDecimals);
          double apy = 0;
          if (totalCDPs[token].collateral > BigInt.zero &&
              marketPrices[token] != null &&
              incentives[token] != null) {
            incentives[token].forEach((e) {
              apy += (marketPrices[e.token] ?? 0) *
                  e.amount /
                  Fmt.bigIntToDouble(
                      rewards[token]?.sharesTotal, collateralDecimals) /
                  marketPrices[token];
            });
          }
          final deposit = Fmt.priceFloorBigInt(
              loans[token]?.collaterals, collateralDecimals);

          bool canClaim = false;
          double loyaltyBonus = 0;
          if (incentives[token] != null) {
            loyaltyBonus = incentives[token][0].deduction;
          }

          final reward = rewards[token];
          final rewardView = reward != null && reward.reward.length > 0
              ? reward.reward.map((e) {
                  final amount = double.parse(e['amount']);
                  if (amount > 0.0001) {
                    canClaim = true;
                  }
                  return '${Fmt.priceFloor(amount * (1 - loyaltyBonus))}';
                }).join(' + ')
              : '0.00';
          final shouldActivate = reward?.shares != loans[token]?.collaterals;

          final bestNumber = plugin.store.gov.bestNumber;
          final blocksToEnd = dex_incentive_loyalty_end_block[token] != null
              ? dex_incentive_loyalty_end_block[token] - bestNumber.toInt()
              : null;

          return RoundedCard(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                          margin: EdgeInsets.only(right: 8),
                          child: TokenIcon(token, tokenIcons)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dic['loan.collateral'],
                              style: TextStyle(fontSize: 12)),
                          Text('$deposit ${PluginFmt.tokenView(token)}',
                              style: TextStyle(
                                fontSize: 20,
                                letterSpacing: -0.8,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              )),
                          Text(
                            '≈ \$${Fmt.priceFloor(collateralValue)}',
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      Expanded(child: Container(width: 2)),
                      OutlinedButtonSmall(
                        margin: EdgeInsets.all(0),
                        active: canClaim,
                        content: dic['earn.claim'],
                        onPressed: canClaim
                            ? () => _onClaimReward(context, token, rewardView)
                            : null,
                      )
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${dic['earn.reward']} ($incentiveTokenSymbol)',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  rewardView,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.8,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Visibility(
                    visible: rewardView.isNotEmpty && shouldActivate,
                    child: Container(
                      margin: EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            child: Text(
                              dic['loan.activate.1'],
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).primaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () => _activateRewards(context, token),
                          ),
                          Container(
                            margin: EdgeInsets.only(left: 4),
                            child: Text(
                              dic['loan.activate.2'],
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    )),
                Container(
                  margin: EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      InfoItem(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        title: '${dic['earn.apy']} ($incentiveTokenSymbol)',
                        content: Fmt.ratio(apy),
                        color: Theme.of(context).primaryColor,
                      ),
                      InfoItem(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        title: '${dic['earn.apy.0']} ($incentiveTokenSymbol)',
                        content: Fmt.ratio(apy * (1 - loyaltyBonus)),
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TapTooltip(
                        message: dic['earn.loyal.info'],
                        child: Center(
                            child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info,
                              color: Theme.of(context).disabledColor,
                              size: 14,
                            ),
                            Container(
                              margin: EdgeInsets.only(left: 4),
                              child: Text(dic['earn.loyal'] + ':',
                                  style: TextStyle(fontSize: 12)),
                            )
                          ],
                        )),
                      ),
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        child: Text(
                          Fmt.ratio(loyaltyBonus),
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
                Visibility(
                    visible: blocksToEnd != null,
                    child: Container(
                      margin: EdgeInsets.only(top: 4),
                      child: Text(
                        '${dic['earn.loyal.end']}: ${Fmt.blockToTime(blocksToEnd ?? 0, 12500)}',
                        style: TextStyle(fontSize: 10),
                      ),
                    )),
                Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButtonSmall(
                        content: dic['loan.withdraw'],
                        active: false,
                        padding: EdgeInsets.only(top: 8, bottom: 8),
                        margin: EdgeInsets.only(right: 8),
                        onPressed: loans[token].collaterals > BigInt.zero
                            ? () => Navigator.of(context).pushNamed(
                                  LoanDepositPage.route,
                                  arguments: LoanDepositPageParams(
                                      LoanDepositPage.actionTypeWithdraw,
                                      token),
                                )
                            : null,
                      ),
                    ),
                    Expanded(
                      child: OutlinedButtonSmall(
                        content: dic['loan.deposit'],
                        active: true,
                        padding: EdgeInsets.only(top: 8, bottom: 8),
                        margin: EdgeInsets.only(left: 8),
                        onPressed: () => Navigator.of(context).pushNamed(
                          LoanDepositPage.route,
                          arguments: LoanDepositPageParams(
                              LoanDepositPage.actionTypeDeposit, token),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
  }
}
