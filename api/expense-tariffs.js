// Tariffario applicativo concordato per il primo rilascio delle note spese.
// Quando cambia una tariffa, mantenere le versioni precedenti per applicare
// sempre i valori validi alla data della gara.
export const DEFAULT_EXPENSE_TARIFFS = Object.freeze({
  versions: [
    {
      id: 'FICr-2026-04-01',
      validFrom: '2026-04-01',
      kmRate: 0.36,
      holidayMultiplier: 2,
      ordinary: { baseHours: 4, baseAmount: 30, additionalHourly: 6 },
      specialist: { baseHours: 4, baseAmount: 40, additionalHourly: 10 },
      dataProcessingDaily: 70,
      equipment: { standardScoreboard: 50, transmission: 5, idCam: 15 },
      sports: {
        'atletica - strada': { dailyOrganization: 50, intermediate: 20 },
        'atletica - pista': { dailyOrganization: 50 },
        'ciclismo su strada': { dailyOrganization: 50, intermediate: 20 },
        corsa: { dailyOrganization: 50, intermediate: 20 },
        'corsa - fidal': {
          manualReview: true,
          manualReviewMessage: 'Applicare la convenzione FIDAL vigente.',
        },
        'corsa in montagna': { dailyOrganization: 50 },
        'hockey ghiaccio': { dailyOrganization: 7 },
        nuoto: { dailyOrganization: 50 },
        rally: {
          manualReview: true,
          manualReviewMessage:
            'Le gare Rally richiedono il calcolo manuale per postazioni e passaggi.',
        },
        'regolarita auto': {
          manualReview: true,
          manualReviewMessage:
            'Indicare e verificare manualmente il numero di postazioni di regolarità.',
        },
        'regolarita storiche': {
          manualReview: true,
          manualReviewMessage:
            'Indicare e verificare manualmente il numero di postazioni di regolarità.',
        },
        'sci alpinismo': {
          manualReview: true,
          manualReviewMessage:
            'Disciplina non presente nel tariffario automatico configurato.',
        },
        'sci alpino fis': { dailyOrganization: 100, intermediate: 20 },
        'sci alpino fisi': { dailyOrganization: 50, intermediate: 20 },
        'sci nordico / biathlon fisi': { dailyOrganization: 50 },
        'sci nordico / biathlon fis': { dailyOrganization: 100 },
        'snowboard fisi': { dailyOrganization: 50 },
        'snowboard fis': { dailyOrganization: 100 },
        'altro (specificare)': {
          manualReview: true,
          manualReviewMessage: 'Sport da valorizzare manualmente.',
        },
      },
    },
  ],
});
