// Flag low stock: one query for the low-stock cards that are not flagged
// yet, then one update that ticks the checkbox on all of them.
morkva.action('flagLow', async (input, ctx) => {
  // A test run wraps the button trigger as {kind: 'test', as}. It passes
  // no card ids, so it checks the whole collection.
  const test = ctx.trigger.kind === 'test';
  const trigger = ctx.trigger.kind === 'test' ? ctx.trigger.as : ctx.trigger;
  if (trigger.kind !== 'button' || trigger.scope !== 'collection') {
    return 'Run it from a collection button';
  }
  // A button run handles only the cards shown in the view it was pressed on.
  const shown = new Set(trigger.cardIds);
  if (!test && shown.size === 0) return 'No products shown';
  const collection = trigger.collectionId;

  const low = [];
  /** @type {CardsQueryResult | CardsPageResult} */
  let page = await morkva.call('cards.query', {
    collection,
    where: [
      { field: input.stockField, op: 'lessThan', value: input.below },
      { field: input.flagField, op: 'isFalse' },
    ],
    limit: 100,
  });
  for (;;) {
    for (const row of page.rows) {
      if (test || shown.has(row.id)) low.push(row.id);
    }
    morkva.progress({ done: low.length, total: page.total, label: 'Checking stock' });
    if (!page.nextCursor) break;
    page = await morkva.call('cards.page', {
      handle: page.handle,
      cursor: page.nextCursor,
    });
  }
  if (low.length === 0) return 'No products to flag';

  await morkva.call('cards.update', {
    collection,
    target: { ids: low },
    set: { [input.flagField]: true },
  });
  return `Flagged ${low.length} product${low.length === 1 ? '' : 's'}`;
});
