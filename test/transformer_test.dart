import 'package:test/test.dart';
import 'package:ynab_csv/crypto.dart';
import 'package:ynab_csv/model.dart';
import 'package:ynab_csv/transformer.dart';

class TestCrypto with Crypto {
  @override
  String sha1AsBase64(String input) => input;
}

void main() {
  group('isForHeader', () {
    final revolut = RevolutTransformer(crypto: TestCrypto(), fileName: '', accounts: {});
    final kbcAccount = KbcAccountTransformer(crypto: TestCrypto(), accounts: {});
    final kbcCard = KbcCreditCardTransformer(crypto: TestCrypto(), accounts: {});
    test('Revolut', () {
      final header =
          'Completed Date;Reference;Paid Out (EUR);Paid In (EUR);Exchange Out;Exchange In; Balance (EUR);Exchange Rate;Category'
              .split(';');

      expect(revolut.isForHeader(header), true);
      expect(kbcAccount.isForHeader(header), false);
      expect(kbcCard.isForHeader(header), false);
    });

    group('kbc account NL', () {
      final header =
          'Rekeningnummer;Rubrieknaam;Naam;Munt;Afschriftnummer;Datum;Omschrijving;Valuta;Bedrag;Saldo;Credit;Debet;Rekening tegenpartij;BIC code tegenpartij;Naam tegenpartij;Adres tegenpartij;gestructureerde mededeling;vrije mededeling'
              .split(';');

      test('Is For', () {
        expect(revolut.isForHeader(header), false);
        expect(kbcAccount.isForHeader(header), true);
        expect(kbcCard.isForHeader(header), false);
      });
    });

    group('kbc account EN', () {
      final header =
          "Account number;Heading;Name;Currency;Statement number;Date;Description;Value date;Amount;Balance;credit;debit;counterparty's account number;Counterparty BIC;Counterparty name;Counterparty address;standard-format reference;Free-format reference"
              .split(';');

      test('Is For', () {
        expect(revolut.isForHeader(header), false);
        expect(kbcAccount.isForHeader(header), true);
        expect(kbcCard.isForHeader(header), false);
      });
    });

    group('kbc credit card NL', () {
      final header =
          'kredietkaart;kaarthouder;uitgavenstaat;datum verrichting;Datum verrekening;bedrag;credit;debet;munt;koers;bedrag in EUR;Kosten op verrichting;Handelaar;locatie;land;toelichting'
              .split(';');

      test('Is For', () {
        expect(revolut.isForHeader(header), false);
        expect(kbcAccount.isForHeader(header), false);
        expect(kbcCard.isForHeader(header), true);
      });
    });

    group('kbc credit card EN', () {
      final header =
          'credit card;card holder;Billing statement;date transaction;Settlement date;amount;credit;debit;currency;price;amount in EUR;Transaction cost;Merchant;location;country;explanation'
              .split(';');

      test('Is For', () {
        expect(revolut.isForHeader(header), false);
        expect(kbcAccount.isForHeader(header), false);
        expect(kbcCard.isForHeader(header), true);
      });
    });
  });

  group('revolut parsing', () {
    final yearInFileName = '2019';
    final fileName = 'Revolut-EUR-Statement-1 Jan $yearInFileName to 31 Dec $yearInFileName.csv';
    final transformer = RevolutTransformer(
      crypto: TestCrypto(),
      fileName: fileName,
      accounts: {'Revolut': 'expectedAccountId'},
    );

    final def = '28 October 2019;To KG;4,25 ;;;;326,14 ; ;Transfers'.split(';');

    test('Full', () {
      final input = List.of(def);
      final output = transformer.from(input);
      expect(
        output,
        YnabApiTransaction(
          accountId: 'expectedAccountId',
          date: '2019-10-28',
          amount: -4250,
          payeeName: 'To KG',
          importId: '28 October 2019To KG4,25 326,14 Transfers',
          cleared: 'cleared',
        ),
      );
    });

    test('Incoming', () {
      final input = List.of(def);
      input[RevolutColumn.paidIn.index] = '123,45';
      input[RevolutColumn.paidOut.index] = null;
      expect(transformer.from(input).amount, 123450);
    });

    test('Outgoing', () {
      final input = List.of(def);
      input[RevolutColumn.paidOut.index] = '1.123,45';
      input[RevolutColumn.paidIn.index] = null;
      expect(transformer.from(input).amount, -1123450);
    });

    test('Date Without Year', () {
      final input = List.of(def);
      input[RevolutColumn.completedDate.index] = '12 July';
      expect(transformer.from(input).date, '$yearInFileName-07-12');
    });

    test('Date With Year', () {
      final input = List.of(def);
      input[RevolutColumn.completedDate.index] = '12 July 2018';
      expect(transformer.from(input).date, '2018-07-12');
    });
  });

  group('kbc account parsing', () {
    final transformer = KbcAccountTransformer(
      accounts: {'BE12345678901234': 'expectedAccountId'},
      crypto: TestCrypto(),
    );

    final def =
        'BE12 3456 7890 1234;TWIN;MP;EUR;2020006;08/01/2020;Description;09/01/2020;-0,85;1199,54;;-0,85;;;Counterparty;;;Memo;'
            .split(';');

    test('Full', () {
      final input = List.of(def);
      final output = transformer.from(input);
      expect(
        output,
        YnabApiTransaction(
          accountId: 'expectedAccountId',
          amount: -850,
          payeeName: 'Counterparty',
          date: '2020-01-08',
          memo: 'Memo',
          importId: 'BE12345678901234TWINMPEUR08/01/2020Description09/01/2020-0,851199,54-0,85CounterpartyMemo',
          cleared: 'cleared',
        ),
      );
    });

    test('With payee', () {
      final input = List.of(def);
      input[KbcAccountColumn.counterPartyName.index] = 'Payee';
      input[KbcAccountColumn.description.index] = 'Description';
      expect(transformer.from(input).payeeName, 'Payee');
    });

    test('Without payee', () {
      final input = List.of(def);
      input[KbcAccountColumn.counterPartyName.index] = null;
      input[KbcAccountColumn.description.index] = 'Description';
      expect(transformer.from(input).payeeName, 'Description');
    });

    test('Outgoing', () {
      final input = List.of(def);
      input[KbcAccountColumn.amount.index] = '-123,45';
      expect(transformer.from(input).amount, -123450);
    });

    test('Incoming', () {
      final input = List.of(def);
      input[KbcAccountColumn.amount.index] = '123,45';
      expect(transformer.from(input).amount, 123450);
    });

    test('Payee filled', () {
      final input = List.of(def);
      input[KbcAccountColumn.counterPartyName.index] = 'Name';
      input[KbcAccountColumn.referenceFree.index] = 'reference';
      expect(transformer.from(input).payeeName, 'Name');
      expect(transformer.from(input).memo, 'reference');
    });

    test('No payee, unknown description type', () {
      final input = List.of(def);
      input[KbcAccountColumn.counterPartyName.index] = null;
      input[KbcAccountColumn.description.index] = 'Description';
      input[KbcAccountColumn.referenceFree.index] = 'reference';
      expect(transformer.from(input).payeeName, 'Description');
      expect(transformer.from(input).memo, 'reference');
    });

    test('No payee, known description type', () {
      final input = List.of(def);
      input[KbcAccountColumn.counterPartyName.index] = null;
      input[KbcAccountColumn.description.index] =
          'EUROPEAN DIRECT DEBIT                31-12 CREDITOR        : PAYPAL (EUROPE) S.A.R.L. ET CIE., S CREDITOR REF.   : 112323131231 PAYPAL MANDATE REF.    : ABCDEFGHTHHT OWN DESCRIPTION : ABCDEFGHTHHT REFERENCE       : 121212121122 PAYPAL';
      expect(transformer.from(input).payeeName, 'PAYPAL (EUROPE) S.A.R.L. ET CIE., S');
      expect(transformer.from(input).memo, '121212121122 PAYPAL');
    });
  });

  group('kbc account parsing', () {
    final transformer = KbcCreditCardTransformer(
      accounts: {'123456XXXXXX4321': 'expectedAccountId'},
      crypto: TestCrypto(),
    );

    final def =
        '123456XXXXXX4321;MP;                 ;21/12/2019;23/12/2019;5,490000000;5,490000000;                        ;EUR;1,000000000;-5,49;0,00;PAYPAL *APPLE.COM/BILL;123123123;United Kingdom;United Kingdom - 123123123;'
            .split(';');

    test('Full', () {
      final input = List.of(def);
      final output = transformer.from(input);
      expect(
        output,
        YnabApiTransaction(
          accountId: 'expectedAccountId',
          payeeName: 'PAYPAL *APPLE.COM/BILL',
          amount: -5490,
          memo: 'United Kingdom - 123123123',
          date: '2019-12-21',
          importId:
              '123456XXXXXX4321MP21/12/201923/12/20195,4900000005,490000000EUR1,000000000-5,490,00PAYPAL *APPLE.COM/BILL123123123United KingdomUnited Kingdom - 123123123',
          cleared: 'cleared',
        ),
      );
    });

    test('Empty card should return null', () {
      final input = List.of(def);
      input[KbcCCColumn.card.index] = null;
      final output = transformer.from(input);
      expect(output, null);
    });
  });
}
