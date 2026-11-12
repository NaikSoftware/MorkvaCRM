// Copy order total to client: reads the order's client link and total, then
// plans one update on the client card. A link value holds card ids only, so
// the client collection is a setting (`format: collection`); it must be in
// the module's consent too, or the run fails.
morkva.action('copyTotal', async (input, ctx) => {
  const order = ctx.card;
  if (!order || !('values' in order)) return 'No order';
  const links = order.values[input.clientField];
  const client = Array.isArray(links) ? links[0] : undefined;
  if (!client) return `${order.title} has no client`;
  const total = order.values[input.totalField];
  if (typeof total !== 'number') return `${order.title} has no total`;

  const name = client.title || 'the client';
  try {
    // Refused with "Collection not available to this module" when the
    // consent leaves out the client collection.
    await morkva.call('cards.update', {
      collection: input.clients,
      target: { ids: [client.id] },
      set: { [input.targetField]: total },
    });
  } catch (e) {
    // The client already holds this total: nothing to do, not a failure.
    if (/** @type {MorkvaError} */ (e).code === 'no_change') {
      return `${name} is up to date`;
    }
    throw e;
  }
  return `Copied ${total} to ${name}`;
});
