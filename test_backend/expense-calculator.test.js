import assert from 'node:assert/strict';
import test from 'node:test';

import {
  calculateExpenseReport,
  isFederalHoliday,
  parseExpenseTariffs,
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
