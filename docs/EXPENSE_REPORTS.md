# Note spese amministrative

Il calcolo viene eseguito dal backend quando un rapportino viene validato. Il
risultato, comprensivo della versione tariffaria applicata, viene salvato nella
proprietà Notion `NOTA SPESE APP` della gara principale.

Il tariffario predefinito è versionato nel backend in
`api/expense-tariffs.js`; non viene inserito nel bundle Flutter. In futuro può
essere sostituito senza modifiche al motore impostando la variabile backend
`EXPENSE_TARIFFS_JSON`, con questa struttura generale:

```json
{
  "versions": [
    {
      "id": "nome-versione",
      "validFrom": "YYYY-MM-DD",
      "kmRate": 0,
      "ordinary": {},
      "specialist": {},
      "equipment": {},
      "sports": {}
    }
  ]
}
```

Ogni nuova versione va aggiunta mantenendo le precedenti: il backend seleziona
quella con `validFrom` più recente ma non successiva alla data della gara. I
consuntivi calcolati vengono conservati in Notion e sono accessibili soltanto
agli amministratori.

Le gare per cui mancano dati sufficienti (per esempio Rally, convenzioni o
attrezzature non standard) vengono calcolate per la parte determinabile e
marcate come `Verifica manuale richiesta`.
