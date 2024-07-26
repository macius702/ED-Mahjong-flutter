import 'dart:ui';

import 'package:ed_mahjong/engine/pieces/mahjong_tile.dart';
import 'package:ed_mahjong/engine/tileset/tileset_meta.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show DefaultAssetBundle, BuildContext;
import 'package:path/path.dart';

class TilesetRenderer {
  static const baseFolder = 'assets/tilesets';

  static Future<TilesetRenderer> load(
      BuildContext context, TilesetMeta tileset) async {
    final assetBundle = DefaultAssetBundle.of(context);
    final folder =
        '${baseFolder}/${basenameWithoutExtension(tileset.fileName)}';

    var baseTile = loadImage(assetBundle, tileset, "${folder}/TILE_1");
    final images = await Future.wait<Image>([
      baseTile,
      darkenImage(tileset, baseTile),
      loadImage(assetBundle, tileset, "${folder}/TILE_1_SEL"),
      ...MahjongTile.values.map((tile) =>
          loadImage(assetBundle, tileset, "${folder}/${tileToString(tile)}")),
    ]);

    final Map<MahjongTile, Image> faceImg = {};
    for (var i = 0; i < MahjongTile.values.length; ++i) {
      faceImg[MahjongTile.values[i]] = images[3 + i];
    }

    return TilesetRenderer._(images[0], images[1], images[2], faceImg);
  }

  final Image tile;
  final Image tileDark;
  final Image tileSel;
  final Map<MahjongTile, Image> faceImg;
  TilesetRenderer._(this.tile, this.tileDark, this.tileSel, this.faceImg);

  static Future<Image> loadImage(
      AssetBundle bundle, TilesetMeta meta, String image) async {
    ByteData bd = await bundle.load("$image.png");

    final Uint8List bytes = Uint8List.view(bd.buffer);

    final Codec codec = await instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }

  static Future<Image> darkenImage(
      TilesetMeta tileset, Future<Image> image) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the original image
    Image originalImage = await image;
    canvas.drawImage(originalImage, Offset.zero, Paint());

    // Draw a semi-transparent black layer over the image
    canvas.drawRect(
      Rect.fromLTWH(0, 0, originalImage.width.toDouble(),
          originalImage.height.toDouble()),
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.5),
    );

    return await recorder
        .endRecording()
        .toImage(tileset.tileWidth, tileset.tileHeight);
  }
}
