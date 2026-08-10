function numberValue(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  const parsed = Number(String(value ?? '').trim().replace(',', '.'));
  return Number.isFinite(parsed) ? parsed : 0;
}

function positiveInteger(value, fallback = 0) {
  const parsed = Math.floor(numberValue(value));
  return parsed > 0 ? parsed : fallback;
}

function normalizedKey(value) {
  return String(value ?? '')
    .trim()
    .toLocaleLowerCase('it-IT')
    .replace(/\s+/g, ' ');
}

function roundCurrency(value) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function easterSunday(year) {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(Date.UTC(year, month - 1, day));
}

export function isFederalHoliday(dateText) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(dateText ?? ''))) return false;
  const date = new Date(`${dateText}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return false;
  const monthDay = dateText.slice(5);
  if (['01-01', '05-01', '12-25', '12-26'].includes(monthDay)) return true;
  const easter = easterSunday(date.getUTCFullYear());
  const easterMonday = new Date(easter.getTime() + 86400000);
  return date.getTime() === easter.getTime() || date.getTime() === easterMonday.getTime();
}

function tariffForDate(config, dateText) {
  const versions = Array.isArray(config?.versions) ? config.versions : [];
  return versions
    .filter((version) => /^\d{4}-\d{2}-\d{2}$/.test(version?.validFrom ?? ''))
    .filter((version) => version.validFrom <= dateText)
    .sort((left, right) => right.validFrom.localeCompare(left.validFrom))[0] ?? null;
}

function timekeeperAmount(hours, tariff) {
  if (hours <= 0) return 0;
  const baseHours = positiveInteger(tariff?.baseHours, 4);
  const baseAmount = numberValue(tariff?.baseAmount);
  const additionalHourly = numberValue(tariff?.additionalHourly);
  const wholeHours = Math.floor(hours);
  const fraction = hours - wholeHours;
  const billableHours = wholeHours + (fraction > 0.5 ? 1 : 0);
  return roundCurrency(
    baseAmount + Math.max(0, billableHours - baseHours) * additionalHourly,
  );
}

function addLine(lines, line) {
  const amount = roundCurrency(numberValue(line.amount));
  if (amount === 0) return;
  lines.push({ ...line, amount });
}

function activeDates(report) {
  const dates = new Set();
  for (const row of Array.isArray(report?.cronometristi) ? report.cronometristi : []) {
    for (const day of Array.isArray(row?.giorni) ? row.giorni : []) {
      const date = String(day?.data ?? '').trim();
      if (/^\d{4}-\d{2}-\d{2}$/.test(date)) dates.add(date);
    }
  }
  if (dates.size === 0) {
    for (const date of Array.isArray(report?.pacchetto?.giornate)
      ? report.pacchetto.giornate
      : []) {
      if (/^\d{4}-\d{2}-\d{2}$/.test(String(date))) dates.add(String(date));
    }
  }
  return [...dates].sort();
}

export function calculateExpenseReport(report, config, { calculatedAt = new Date() } = {}) {
  const dates = activeDates(report);
  const referenceDate = dates[0] || String(report?.gara?.dataDa ?? '').trim();
  const tariff = tariffForDate(config, referenceDate);
  if (!tariff) throw new Error('No expense tariff configured for the race date');

  const lines = [];
  const warnings = [];
  const timekeepers = Array.isArray(report?.cronometristi) ? report.cronometristi : [];
  const holidayMultiplier = numberValue(tariff.holidayMultiplier) || 2;
  const dataProcessingDates = new Set();

  for (const row of timekeepers) {
    const name = String(row?.nome ?? '').trim() || 'Cronometrista';
    const specialist = String(row?.segreteria ?? '').trim().toUpperCase() === 'SI';
    const hourlyTariff = specialist ? tariff.specialist : tariff.ordinary;
    for (const day of Array.isArray(row?.giorni) ? row.giorni : []) {
      const date = String(day?.data ?? '').trim();
      const hours = numberValue(day?.ore);
      const multiplier = isFederalHoliday(date) ? holidayMultiplier : 1;
      const hourlyAmount = timekeeperAmount(hours, hourlyTariff) * multiplier;
      addLine(lines, {
        category: 'personnel',
        subtype: specialist ? 'specialist' : 'ordinary',
        label: `${specialist ? 'Indennità specialistica' : 'Indennità ordinaria'} · ${name}`,
        date,
        quantity: hours,
        unit: 'ore',
        amount: hourlyAmount,
      });
      if (specialist && hours > 0 && date) dataProcessingDates.add(date);

      const km = numberValue(day?.km);
      addLine(lines, {
        category: 'travel',
        label: `Rimborso chilometrico · ${name}`,
        date,
        quantity: km,
        unit: 'km',
        unitRate: numberValue(tariff.kmRate),
        amount: km * numberValue(tariff.kmRate),
      });

      const otherExpenses = numberValue(day?.spese);
      addLine(lines, {
        category: 'other',
        label: `Altre spese dichiarate · ${name}`,
        date,
        quantity: 1,
        unit: 'voce',
        amount: otherExpenses,
      });
    }
  }

  const sport = String(report?.gara?.sport ?? report?.garaOrigine?.sport ?? '').trim();
  const sportRule = tariff.sports?.[normalizedKey(sport)] ?? null;
  if (!sportRule) {
    warnings.push(`Sport “${sport || 'non indicato'}” non presente nel tariffario automatico.`);
  } else if (sportRule.manualReview === true) {
    warnings.push(sportRule.manualReviewMessage || `Il calcolo di ${sport} richiede verifica manuale.`);
  } else {
    addLine(lines, {
      category: 'organization',
      label: `Contributo organizzativo · ${sport}`,
      quantity: dates.length,
      unit: 'giorni',
      unitRate: numberValue(sportRule.dailyOrganization),
      amount: dates.length * numberValue(sportRule.dailyOrganization),
    });
  }

  if (dataProcessingDates.size > 0 && sportRule?.dataProcessingIncluded !== true) {
    addLine(lines, {
      category: 'equipment',
      label: 'Elaborazione dati',
      quantity: dataProcessingDates.size,
      unit: 'giorni',
      unitRate: numberValue(tariff.dataProcessingDaily),
      amount: dataProcessingDates.size * numberValue(tariff.dataProcessingDaily),
    });
  }

  const equipmentRows = Array.isArray(report?.apparecchiature)
    ? report.apparecchiature
    : [];
  const equipment = equipmentRows.find((row) => row?.guidedMode === true) ?? {};
  const equipmentRates = tariff.equipment ?? {};
  const equipmentDays = Math.max(dates.length, 1);
  const equipmentUnit =
    equipmentDays === 1 ? 'unità' : `unità × ${equipmentDays} giorni`;
  const countIfYes = (field, countField) =>
    String(equipment?.[field] ?? '').toUpperCase() === 'SI'
      ? positiveInteger(equipment?.[countField], 1)
      : 0;

  const scoreboards = countIfYes('tabellone', 'tabelloneNumero');
  addLine(lines, {
    category: 'equipment',
    label: 'Tabellone standard',
    quantity: scoreboards,
    unit: equipmentUnit,
    unitRate: numberValue(equipmentRates.standardScoreboard),
    amount:
      scoreboards * numberValue(equipmentRates.standardScoreboard) * equipmentDays,
  });

  const intermediates = countIfYes('intermedi', 'intermediNumero');
  if (intermediates > 0 && numberValue(sportRule?.intermediate) > 0) {
    addLine(lines, {
      category: 'equipment',
      label: 'Postazioni intermedie',
      quantity: intermediates,
      unit: 'postazioni',
      unitRate: numberValue(sportRule.intermediate),
      amount: intermediates * numberValue(sportRule.intermediate),
    });
  } else if (intermediates > 0) {
    warnings.push('Intermedi presenti: tariffa da verificare manualmente per questo sport.');
  }

  const transmissions = countIfYes('trasmissioneDati', 'trasmissioneDatiNumero');
  addLine(lines, {
    category: 'equipment',
    label: 'Dispositivi di trasmissione dati',
    quantity: transmissions,
    unit: equipmentUnit,
    unitRate: numberValue(equipmentRates.transmission),
    amount: transmissions * numberValue(equipmentRates.transmission) * equipmentDays,
  });

  const idCams = countIfYes('IDcam', 'IDcamNumero');
  addLine(lines, {
    category: 'equipment',
    label: 'IDcam',
    quantity: idCams,
    unit: equipmentUnit,
    unitRate: numberValue(equipmentRates.idCam),
    amount: idCams * numberValue(equipmentRates.idCam) * equipmentDays,
  });

  if (String(equipment?.altreApparecchiature ?? '').trim()) {
    warnings.push('Sono presenti altre apparecchiature da valorizzare manualmente.');
  }

  const totalsByCategory = {};
  for (const line of lines) {
    totalsByCategory[line.category] = roundCurrency(
      numberValue(totalsByCategory[line.category]) + line.amount,
    );
  }
  const total = roundCurrency(lines.reduce((sum, line) => sum + line.amount, 0));

  return {
    schemaVersion: 1,
    tariffVersion: String(tariff.id ?? tariff.validFrom),
    tariffValidFrom: tariff.validFrom,
    calculatedAt: calculatedAt.toISOString(),
    race: {
      title: String(report?.gara?.nome ?? report?.garaOrigine?.titolo ?? '').trim(),
      sport,
      startDate: referenceDate,
      endDate: dates.at(-1) ?? referenceDate,
      location: String(report?.gara?.luogo ?? report?.garaOrigine?.luogo ?? '').trim(),
    },
    lines,
    totalsByCategory,
    total,
    requiresManualReview: warnings.length > 0,
    warnings,
  };
}

export function summarizeExpenseEstimate(estimate, report) {
  const sourceLines = Array.isArray(estimate?.lines) ? estimate.lines : [];
  const timekeepers = Array.isArray(report?.cronometristi) ? report.cronometristi : [];
  const activeTimekeepers = timekeepers.filter((row) =>
    (Array.isArray(row?.giorni) ? row.giorni : []).some(
      (day) => numberValue(day?.ore) > 0,
    ),
  );
  const countByType = (specialist) =>
    activeTimekeepers.filter(
      (row) =>
        (String(row?.segreteria ?? '').trim().toUpperCase() === 'SI') === specialist,
    ).length;
  const sumLines = (category, subtype) =>
    roundCurrency(
      sourceLines
        .filter(
          (line) =>
            line?.category === category &&
            (subtype == null || line?.subtype === subtype),
        )
        .reduce((sum, line) => sum + numberValue(line?.amount), 0),
    );

  const lines = [];
  const addPersonnelSummary = (subtype, label, count) => {
    addLine(lines, {
      category: 'personnel',
      subtype,
      label: `${label} per ${count} crono`,
      quantity: count,
      unit: 'crono',
      amount: sumLines('personnel', subtype),
    });
  };
  addPersonnelSummary('ordinary', 'Indennità ordinaria', countByType(false));
  addPersonnelSummary(
    'specialist',
    'Indennità specialistica',
    countByType(true),
  );

  const travelLines = sourceLines.filter((line) => line?.category === 'travel');
  const totalKm = roundCurrency(
    travelLines.reduce((sum, line) => sum + numberValue(line?.quantity), 0),
  );
  addLine(lines, {
    category: 'travel',
    label: `Rimborso chilometrico per ${totalKm} km`,
    quantity: totalKm,
    unit: 'km',
    unitRate: travelLines.find((line) => line?.unitRate != null)?.unitRate,
    amount: sumLines('travel'),
  });

  addLine(lines, {
    category: 'other',
    label: 'Altre spese complessive',
    quantity: 1,
    unit: 'voce',
    amount: sumLines('other'),
  });
  lines.push(
    ...sourceLines.filter(
      (line) => !['personnel', 'travel', 'other'].includes(line?.category),
    ),
  );

  return { ...estimate, lines };
}

export function parseExpenseTariffs(rawValue) {
  if (typeof rawValue !== 'string' || !rawValue.trim()) {
    throw new Error('Missing EXPENSE_TARIFFS_JSON configuration');
  }
  const parsed = JSON.parse(rawValue);
  if (!Array.isArray(parsed?.versions) || parsed.versions.length === 0) {
    throw new Error('Invalid EXPENSE_TARIFFS_JSON configuration');
  }
  return parsed;
}
