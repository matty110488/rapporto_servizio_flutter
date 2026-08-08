import assert from 'node:assert/strict';
import test from 'node:test';

import {
  calculateExpenseReport,
  isFederalHoliday,
  parseExpenseTariffs,
  summarizeExpenseEstimate,
} from '../api/expense-calculator.js';
import { DEFAULT_EXPENSE_TARIFFS } from '../api/expense-tariffs.js';

const config = {
  versions: [
    {
      id: 'test-2026',
      validFrom: '2026-04-01',
      kmRate: 0.36,
      holidayMultiplier: 2,
      ordinary: { baseHours: 4, baseAmount: 30, additionalHourly: 6 },
      specialist: { baseHours: 4, baseAmount: 40, additionalHourly: 10 },
      dataProcessingDaily: 70,
      equipment: { standardScoreboard: 50, transmission: 5, idCam: 15 },
      sports: {
        nuoto: { dailyOrganization: 50 },
        corsa: { dailyOrganization: 50, intermediate: 20 },
        rally: {
          manualReview: true,
          manualReviewMessage: 'Rally da verificare manualmente.',
        },
      },
    },
  ],
};

function report({ sport = 'Corsa', date = '2026-06-02' } = {}) {
  return {
    gara: { nome: 'Gara test', sport, luogo: 'Sondrio' },
    cronometristi: [
      {
        nome: 'Mario Rossi',
        segreteria: 'NO',
        giorni: [{ data: date, ore: '5', km: '100', spese: '10' }],
      },
      {
        nome: 'Luigi Bianchi',
        segreteria: 'SI',
        giorni: [{ data: date, ore: '4', km: '', spese: '' }],
      },
    ],
    apparecchiature: [
      {
        guidedMode: true,
        tabellone: 'SI',
        tabelloneNumero: '1',
        intermedi: 'SI',
        intermediNumero: '2',
        trasmissioneDati: 'SI',
        trasmissioneDatiNumero: '2',
        IDcam: 'SI',
        IDcamNumero: '1',
      },
    ],
    pacchetto: { giornate: [date] },
  };
}

test('calculates personnel, travel, organization and equipment details', () => {
  const result = calculateExpenseReport(report(), config, {
    calculatedAt: new Date('2026-06-03T10:00:00Z'),
  });

  assert.equal(result.total, 357);
  assert.deepEqual(result.totalsByCategory, {
    personnel: 76,
    travel: 36,
    other: 10,
    organization: 50,
    equipment: 185,
  });
  assert.equal(result.requiresManualReview, false);
  assert.equal(result.tariffVersion, 'test-2026');
});

test('applies the federal holiday multiplier', () => {
  const holidayReport = report({ date: '2026-05-01' });
  holidayReport.cronometristi = [
    {
      nome: 'Mario Rossi',
      segreteria: 'NO',
      giorni: [{ data: '2026-05-01', ore: '4', km: '', spese: '' }],
    },
  ];
  holidayReport.apparecchiature = [];
  const result = calculateExpenseReport(holidayReport, config);

  assert.equal(isFederalHoliday('2026-05-01'), true);
  assert.equal(result.totalsByCategory.personnel, 60);
});

test('marks Rally as requiring manual review', () => {
  const result = calculateExpenseReport(report({ sport: 'Rally' }), config);
  assert.equal(result.requiresManualReview, true);
  assert.match(result.warnings.join(' '), /Rally/);
});

test('charges scoreboards, transmissions and IDcams for every race day', () => {
  const multiDayReport = report();
  multiDayReport.cronometristi = [];
  multiDayReport.pacchetto.giornate = ['2026-06-03', '2026-06-04'];

  const result = calculateExpenseReport(multiDayReport, config);
  const equipment = Object.fromEntries(
    result.lines
      .filter((line) => line.category === 'equipment')
      .map((line) => [line.label, line]),
  );

  assert.equal(equipment['Tabellone standard'].amount, 100);
  assert.equal(equipment['Dispositivi di trasmissione dati'].amount, 20);
  assert.equal(equipment.IDcam.amount, 30);
  assert.equal(equipment['Tabellone standard'].unit, 'unità × 2 giorni');
  assert.equal(result.totalsByCategory.organization, 100);
});

test('summarizes personnel and travel lines for estimates', () => {
  const sourceReport = report();
  const detailed = calculateExpenseReport(sourceReport, config);
  const summary = summarizeExpenseEstimate(detailed, sourceReport);

  const personnel = summary.lines.filter((line) => line.category === 'personnel');
  const travel = summary.lines.filter((line) => line.category === 'travel');

  assert.equal(personnel.length, 2);
  assert.equal(personnel[0].label, 'Indennità ordinaria per 1 crono');
  assert.equal(personnel[0].amount, 36);
  assert.equal(personnel[1].label, 'Indennità specialistica per 1 crono');
  assert.equal(personnel[1].amount, 40);
  assert.equal(travel.length, 1);
  assert.equal(travel[0].label, 'Rimborso chilometrico per 100 km');
  assert.equal(travel[0].amount, 36);
  assert.equal(summary.total, detailed.total);
});

test('requires tariff configuration from the environment', () => {
  assert.throws(() => parseExpenseTariffs(''), /Missing/);
  assert.deepEqual(parseExpenseTariffs(JSON.stringify(config)), config);
});

test('ships the agreed 2026 tariff in backend code', () => {
  const tariff = DEFAULT_EXPENSE_TARIFFS.versions[0];
  assert.equal(tariff.validFrom, '2026-04-01');
  assert.equal(tariff.kmRate, 0.36);
  assert.equal(tariff.sports.nuoto.dailyOrganization, 50);
  assert.equal(tariff.equipment.standardScoreboard, 50);
});
