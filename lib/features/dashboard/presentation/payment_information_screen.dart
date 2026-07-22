import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../attendance/domain/attendance_categories.dart';

class PaymentInformationScreen extends StatelessWidget {
  const PaymentInformationScreen({super.key, required this.data});
  final Map<String, dynamic> data;

  String money(dynamic value) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2)
          .format(double.tryParse(value?.toString() ?? '0') ?? 0);
  @override
  Widget build(BuildContext context) {
    final finance = Map<String, dynamic>.from(data['financeBreakdown'] ?? {}),
        manual = Map<String, dynamic>.from(data['manualPaymentDetails'] ?? {}),
        history = List.from(data['paymentHistory'] ?? []),
        installments = List.from(data['installments'] ?? []);
    return Scaffold(
        appBar: AppBar(title: const Text('Stall Payment Information')),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
            children: [
              Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.navy, AppColors.green]),
                      borderRadius: BorderRadius.circular(18)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PAYMENT OVERVIEW',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Text(money(data['totalPayable']),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900)),
                        const Text('Total payable',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 9)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: _heroValue('Received Amount',
                                  money(data['amountPaid']))),
                          Expanded(
                              child: _heroValue(
                                  'Balance', money(data['balanceAmount']))),
                          Expanded(
                              child: _heroValue('Status',
                                  _paymentTerm(data['status'] ?? '-')))
                        ])
                      ])),
              _section('PLAN & PAYMENT', [
                _row('Payment mode', sentenceCase(data['paymentMode'])),
                _row('Payment type', sentenceCase(data['paymentType'])),
                _row('Plan', sentenceCase(data['paymentPlanLabel'])),
                _row('Payment ID', data['paymentId']),
                _row('Razorpay order', data['razorpayOrderId']),
                _row('Due date', date(data['paymentDueDate'])),
                _row('Stall conflict',
                    data['stallConflict'] == true ? 'Yes' : 'No')
              ]),
              _section('FINANCIAL BREAKDOWN', [
                _row('Gross amount', money(finance['grossAmount'])),
                _row('Stall discount',
                    '${finance['stallDiscountPercent'] ?? 0}% • ${money(finance['stallDiscountAmount'])}'),
                _row('Payment discount',
                    '${finance['discountPercent'] ?? 0}% • ${money(finance['discountAmount'])}'),
                _row('Taxable subtotal', money(finance['subtotal'])),
                _row('GST', money(finance['gstAmount'])),
                _row('TDS',
                    '${finance['tdsPercent'] ?? data['chosenTdsPercent'] ?? 0}% • ${money(finance['tdsAmount'])}'),
                _row('Net payable', money(finance['netPayable'])),
                if ((double.tryParse(
                            data['penaltyAmount']?.toString() ?? '0') ??
                        0) >
                    0)
                  _row('Penalty',
                      '${money(data['penaltyAmount'])} • ${data['penaltyReason'] ?? ''}')
              ]),
              if (manual.isNotEmpty)
                _section('MANUAL PAYMENT', [
                  _row('Method', sentenceCase(manual['method'])),
                  _row('Transaction ID', manual['transactionId']),
                  _row('Advance', '${manual['advancePercent'] ?? 0}%'),
                  _row('Notes', manual['notes'])
                ]),
              if (installments.isNotEmpty) ...[
                heading('INSTALLMENTS'),
                ...installments.map((raw) {
                  final i = Map<String, dynamic>.from(raw);
                  return Card(
                      margin: const EdgeInsets.only(bottom: 7),
                      child: ListTile(
                          title: Text(
                              i['label'] ??
                                  'Installment ${i['installmentNumber'] ?? ''}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(
                              'Due ${money(i['dueAmount'])} • Received ${money(i['paidAmount'])}\n${date(i['dueDate'])}'),
                          trailing: Text(_paymentTerm(i['status']),
                              style: const TextStyle(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w900))));
                })
              ],
              if (history.isNotEmpty) ...[
                heading('PAYMENT HISTORY'),
                ...history.map((raw) {
                  final h = Map<String, dynamic>.from(raw);
                  return Card(
                      margin: const EdgeInsets.only(bottom: 7),
                      child: ListTile(
                          leading: const Icon(Icons.payments_rounded,
                              color: AppColors.green),
                          title: Text(money(h['amount']),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(
                              '${sentenceCase(h['method'] ?? h['paymentMode'])} • ${h['transactionId'] ?? h['razorpayPaymentId'] ?? ''}\n${date(h['paidAt'])}')));
                })
              ],
            ]));
  }

  String date(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    return d == null
        ? ''
        : DateFormat('d MMM yyyy, h:mm a').format(d.toLocal());
  }

  String _paymentTerm(dynamic raw) => sentenceCase(raw)
      .replaceAll('Advance Paid', 'Advance Received')
      .replaceAll('Partially Paid', 'Partially Received')
      .replaceAll('Paid', 'Received');

  Widget _heroValue(String l, dynamic v) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v?.toString() ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900)),
        Text(l, style: const TextStyle(color: Colors.white54, fontSize: 8))
      ]);
  Widget heading(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 15, 2, 7),
      child: Text(t,
          style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w900,
              color: Colors.black45)));
  Widget _section(String t, List<Widget> rows) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading(t),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: rows)))
      ]);
  Widget _row(String l, dynamic raw) {
    final v = raw?.toString().trim() ?? '';
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(l,
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.black45,
                      fontWeight: FontWeight.w700))),
          Expanded(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900)))
        ]));
  }
}
