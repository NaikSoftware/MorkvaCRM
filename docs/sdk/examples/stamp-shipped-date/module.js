// Stamp shipped date: fills a date field with today when it is empty.
// ctx.card is the card as it was when the button was pressed or the event
// fired. Its values are display forms, and an empty field has no key.
morkva.action('stamp', async (input, ctx) => {
  const card = ctx.card;
  // A CardRef (no values) means the run lacks data:read.
  if (!card || !('values' in card)) return 'No card to stamp';
  const field = input.dateField;
  const name = card.fields[field] || field;
  if (card.values[field] !== undefined) {
    return `${name} is already set on ${card.title}`;
  }
  await morkva.call('cards.update', {
    collection: card.collectionId,
    target: { ids: [card.id] },
    set: { [field]: ctx.today },
  });
  return `Set ${name} to ${ctx.today} on ${card.title}`;
});
