enum PluginType { musicSource, lyrics, metadata }

class ExtensionPlugin {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String iconUrl;
  final String sourceUrl;
  final PluginType type;
  bool isEnabled;

  ExtensionPlugin({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.iconUrl,
    required this.sourceUrl,
    this.type = PluginType.musicSource,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'author': author,
      'description': description,
      'iconUrl': iconUrl,
      'sourceUrl': sourceUrl,
      'type': type.name,
      'isEnabled': isEnabled,
    };
  }

  factory ExtensionPlugin.fromJson(Map<String, dynamic> json) {
    return ExtensionPlugin(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Plugin',
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      iconUrl: json['iconUrl'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      type: PluginType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PluginType.musicSource,
      ),
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}

class ExtensionRepo {
  final String id;
  final String name;
  final String url;
  final String author;
  final String description;
  final List<ExtensionPlugin> plugins;
  final bool isEnabled;

  ExtensionRepo({
    required this.id,
    required this.name,
    required this.url,
    this.author = 'SoundBound Community',
    this.description = 'Music source provider repository',
    this.plugins = const [],
    this.isEnabled = true,
  });

  int get sourceCount => plugins.isNotEmpty ? plugins.length : 1;

  ExtensionRepo copyWith({
    String? id,
    String? name,
    String? url,
    String? author,
    String? description,
    List<ExtensionPlugin>? plugins,
    bool? isEnabled,
  }) {
    return ExtensionRepo(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      author: author ?? this.author,
      description: description ?? this.description,
      plugins: plugins ?? this.plugins,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'author': author,
      'description': description,
      'plugins': plugins.map((p) => p.toJson()).toList(),
      'isEnabled': isEnabled,
    };
  }

  factory ExtensionRepo.fromJson(Map<String, dynamic> json) {
    return ExtensionRepo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Repository',
      url: json['url'] as String? ?? '',
      author: json['author'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      plugins: (json['plugins'] as List<dynamic>?)
              ?.map((p) => ExtensionPlugin.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}
