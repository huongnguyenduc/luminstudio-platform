import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef ProductModelViewerBuilder =
    Widget Function(
      BuildContext context,
      CatalogProductDetail detail,
      Map<String, String> selectedMeshColors,
    );

Widget defaultProductModelViewerBuilder(
  BuildContext context,
  CatalogProductDetail detail,
  Map<String, String> selectedMeshColors,
) {
  return ProductModelViewer(
    detail: detail,
    selectedMeshColors: selectedMeshColors,
  );
}

class ProductModelViewer extends StatefulWidget {
  const ProductModelViewer({
    super.key,
    required this.detail,
    required this.selectedMeshColors,
  });

  final CatalogProductDetail detail;

  /// Currently selected hex colour per mesh id (e.g. `{Claude_Hand: #1E1E1E}`).
  /// Pushed into the live model so the 3D preview matches the swatches.
  final Map<String, String> selectedMeshColors;

  @override
  State<ProductModelViewer> createState() => _ProductModelViewerState();
}

class _ProductModelViewerState extends State<ProductModelViewer> {
  WebViewController? _controller;

  @override
  void didUpdateWidget(covariant ProductModelViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.selectedMeshColors, widget.selectedMeshColors)) {
      _pushColors();
    }
  }

  /// Send the current selection into the running model-viewer. The script set
  /// up in [_recolorScript] re-applies it immediately if the model is loaded,
  /// or stores it to apply on the next `load` event.
  void _pushColors() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final payload = jsonEncode(widget.selectedMeshColors);
    // Swallow errors: the page may still be loading and the helper not yet
    // defined, in which case the embedded initial colours already cover us.
    controller
        .runJavaScript('window.__luminSetColors($payload);')
        .catchError((_) {});
  }

  /// In-page helper that maps mesh ids to material base colours. glTF
  /// `baseColorFactor` is linear, while our swatches are sRGB hex, so we
  /// convert before applying.
  ///
  /// model-viewer's scene graph only exposes *materials*, not the mesh→material
  /// link, and a GLB's material name is not guaranteed to equal the config mesh
  /// id (e.g. the pet tag's mesh `Tag_Base` uses material `Base_Mat`). So we
  /// resolve a colour per material by, in order: a single-config shortcut
  /// (recolour everything), exact name match, shared-token match
  /// (`Tag_Base`↔`Base_Mat` via "base"), and finally pairing by declaration
  /// order as a last resort.
  String _recolorScript() {
    final initial = jsonEncode(widget.selectedMeshColors);
    return '''
(function(){
  window.__luminColors = $initial;
  function hexToLinear(hex){
    hex = String(hex).replace('#','');
    if(hex.length !== 6){ return null; }
    var r = parseInt(hex.substr(0,2),16)/255;
    var g = parseInt(hex.substr(2,2),16)/255;
    var b = parseInt(hex.substr(4,2),16)/255;
    if(isNaN(r) || isNaN(g) || isNaN(b)){ return null; }
    function l(c){ return c <= 0.04045 ? c/12.92 : Math.pow((c+0.055)/1.055, 2.4); }
    return [l(r), l(g), l(b), 1];
  }
  function tokenize(s){
    return String(s).toLowerCase().split(/[^a-z0-9]+/).filter(function(t){
      return t && t !== 'mat' && t !== 'material' && t !== 'mesh';
    });
  }
  function overlap(a, b){
    var n = 0;
    a.forEach(function(t){ if(b.indexOf(t) !== -1){ n++; } });
    return n;
  }
  function paint(mat, hex){
    var lin = hex ? hexToLinear(hex) : null;
    if(lin){
      try { mat.pbrMetallicRoughness.setBaseColorFactor(lin); } catch(e){}
    }
  }
  function apply(){
    var mv = document.querySelector('model-viewer');
    if(!mv || !mv.model){ return; }
    var map = window.__luminColors || {};
    var ids = Object.keys(map);
    if(!ids.length){ return; }
    var materials = mv.model.materials || [];
    if(ids.length === 1){
      materials.forEach(function(mat){ paint(mat, map[ids[0]]); });
      return;
    }
    var cfg = ids.map(function(id){
      return { id: id, color: map[id], tokens: tokenize(id) };
    });
    var matched = false;
    materials.forEach(function(mat){
      var hex = null;
      for(var k=0;k<cfg.length;k++){ if(cfg[k].id === mat.name){ hex = cfg[k].color; break; } }
      if(hex == null){
        var mt = tokenize(mat.name), best = null, bestScore = 0;
        cfg.forEach(function(e){
          var s = overlap(mt, e.tokens);
          if(s > bestScore){ bestScore = s; best = e; }
        });
        if(best && bestScore > 0){ hex = best.color; }
      }
      if(hex != null){ matched = true; paint(mat, hex); }
    });
    if(!matched){
      for(var i=0;i<materials.length && i<cfg.length;i++){ paint(materials[i], cfg[i].color); }
    }
  }
  window.__luminApplyColors = apply;
  window.__luminSetColors = function(map){
    window.__luminColors = map || {};
    apply();
  };
  var mv = document.querySelector('model-viewer');
  if(mv){
    mv.addEventListener('load', apply);
    if(mv.model){ apply(); }
  }
})();
''';
  }

  @override
  Widget build(BuildContext context) {
    final modelUri = widget.detail.modelUri;
    if (modelUri == null) {
      return const _ProductModelUnavailable();
    }

    final theme = Theme.of(context);
    // Paint the page background so the model reads as floating on the page
    // rather than sitting inside a distinct grey panel.
    final backdrop = theme.scaffoldBackgroundColor;

    return Semantics(
      label: 'Interactive 3D viewer for ${widget.detail.name}',
      child: ColoredBox(
        color: backdrop,
        child: ModelViewer(
          key: ValueKey<String>('model-viewer-${widget.detail.id}'),
          src: modelUri.toString(),
          alt: 'Interactive 3D model of ${widget.detail.name}',
          backgroundColor: backdrop,
          cameraControls: true,
          disableZoom: false,
          autoRotate: false,
          ar: false,
          debugLogging: false,
          relatedJs: _recolorScript(),
          onWebViewCreated: (controller) {
            _controller = controller;
          },
        ),
      ),
    );
  }
}

class _ProductModelUnavailable extends StatelessWidget {
  const _ProductModelUnavailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '3D model unavailable',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
