/// Who is calling the harness and what they may plan.
///
/// The transport (the bloc, the agent loop, later the JS bridge) builds the
/// [Actor] and [Grants] itself and puts them on the `HarnessContext`; they are
/// never parsed from a request envelope.
library;

/// What an op needs. Each model-visible op declares exactly one; extra ones
/// can be required per argument (see `Operation.requiredCapabilities`).
enum Capability {
  schemaRead('schema:read'),
  dataRead('data:read'),
  dataWrite('data:write'),
  dataDelete('data:delete'),
  schemaWrite('schema:write'),
  schemaDelete('schema:delete'),
  viewsWrite('views:write'),
  uiNavigate('ui:navigate'),
  modulesRead('modules:read'),
  modulesWrite('modules:write'),
  automationsWrite('automations:write'),

  /// Pseudo-capability of the commit ops. Holding it is not enough: commit
  /// ops also require a user actor, so only the host's user context commits.
  hostCommit('host:commit');

  const Capability(this.wire);

  final String wire;

  static Capability? fromWire(String wire) {
    for (final cap in values) {
      if (cap.wire == wire) return cap;
    }
    return null;
  }
}

/// What a module manifest may ask for: the eight data and UI capabilities.
/// Never `host:commit` nor the module/automation capabilities, so a module
/// cannot install or rebind modules.
const Set<Capability> kModuleGrantable = {
  Capability.schemaRead,
  Capability.dataRead,
  Capability.dataWrite,
  Capability.dataDelete,
  Capability.schemaWrite,
  Capability.schemaDelete,
  Capability.viewsWrite,
  Capability.uiNavigate,
};

/// The assistant's grants: everything but `host:commit`.
final Set<Capability> kAssistantCaps = Set.unmodifiable(
  Capability.values.where((c) => c != Capability.hostCommit),
);

enum ActorKind { user, agent, plugin }

/// The caller's identity, `kind:id` on the wire (`agent:assistant`,
/// `user:<uid>`, `plugin:<moduleId>`).
final class Actor {
  const Actor(this.kind, this.id);

  /// The signed-in person. Only the host (the assistant bloc) builds one; the
  /// agent layer never does.
  const Actor.user(String uid) : this(ActorKind.user, uid);

  const Actor.agent(String id) : this(ActorKind.agent, id);

  const Actor.plugin(String moduleId) : this(ActorKind.plugin, moduleId);

  /// The in-app assistant.
  static const Actor assistant = Actor.agent('assistant');

  /// Parses `kind:id`. Throws [FormatException] on anything else.
  factory Actor.fromWire(String wire) {
    final colon = wire.indexOf(':');
    final kind = colon < 0 ? null : _kindByName(wire.substring(0, colon));
    final id = colon < 0 ? '' : wire.substring(colon + 1);
    if (kind == null || id.isEmpty) {
      throw FormatException('Not an actor "kind:id": "$wire"');
    }
    return Actor(kind, id);
  }

  final ActorKind kind;
  final String id;

  String get wire => '${kind.name}:$id';

  @override
  bool operator ==(Object other) =>
      other is Actor && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => wire;

  static ActorKind? _kindByName(String name) {
    for (final kind in ActorKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// What an actor may plan: a set of capabilities, optionally pinned to some
/// collections. Grants bound what gets *planned*; the plan gate (a user's
/// approval) bounds what gets written.
final class Grants {
  Grants(Iterable<Capability> caps, {Iterable<String>? collections})
    : caps = Set.unmodifiable(caps),
      collections = collections == null ? null : Set.unmodifiable(collections);

  /// Every capability, every collection the user can access. Includes
  /// `host:commit`, which is inert without a user actor. Only the user's own
  /// context holds it.
  factory Grants.all() => Grants(Capability.values);

  /// Parses `{caps: [...] | ["*"], collections: [...] | null}`. `'*'` is
  /// read only for the user's and the assistant's own records; manifests
  /// never go through here.
  factory Grants.fromJson(Map<String, Object?> json) {
    final rawCaps = json['caps'];
    final rawCollections = json['collections'];
    if (rawCaps is! List ||
        (rawCollections != null && rawCollections is! List)) {
      throw const FormatException('Grants need a "caps" list');
    }
    final caps = rawCaps.contains('*')
        ? Capability.values
        : [
            for (final c in rawCaps)
              Capability.fromWire('$c') ??
                  (throw FormatException('Unknown capability "$c"')),
          ];
    return Grants(
      caps,
      collections: (rawCollections as List?)?.map((c) => '$c'),
    );
  }

  final Set<Capability> caps;

  /// The collection ids this actor may touch; null means every collection the
  /// user can access.
  final Set<String>? collections;

  bool allows(Capability cap) => caps.contains(cap);

  bool allowsCollection(String collectionId) =>
      collections == null || collections!.contains(collectionId);

  /// Both grants at once: a plugin's manifest ∩ the user's access.
  Grants intersect(Grants other) => Grants(
    caps.intersection(other.caps),
    collections: switch ((collections, other.collections)) {
      (null, null) => null,
      (final a?, null) => a,
      (null, final b?) => b,
      (final a?, final b?) => a.intersection(b),
    },
  );

  /// Always the explicit list (never `'*'`), so a stored grant never widens
  /// when a capability is added.
  Map<String, Object?> toJson() => {
    'caps': [
      for (final c in Capability.values)
        if (caps.contains(c)) c.wire,
    ],
    'collections': collections == null ? null : (collections!.toList()..sort()),
  };

  @override
  String toString() => 'Grants(${toJson()})';
}
