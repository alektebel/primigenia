extends RefCounted
## Procedural placeholder thumbnails (shaded orb + spur in the category colour).
## The real builder replaces these with 3D renders through studio.set_thumbnail(part_id, texture).

const Placeholder := preload("placeholder/placeholder_view.gd")

static func make(id: String, category: String, size := 72) -> ImageTexture:
	var col: Color = Placeholder.CAT_COLOR.get(category, Color.WHITE)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color("0b1821"))
	var h := id.hash()
	var spur := .35 + float(h % 100) / 100.0 * .5
	var ang := float((h >> 8) % 360) * PI / 180.0 * .5 - PI * .15
	var c := Vector2(size * .45, size * .55)
	var rad := size * (.22 + float((h >> 16) % 10) / 100.0)
	var dirv := Vector2(cos(ang), -sin(ang) - .6).normalized()
	var light := Vector2(-.5, -.6).normalized()
	for y in size:
		for x in size:
			var p := Vector2(x, y)
			var d := p - c
			if d.length() < rad:
				var n := d / rad
				var shade := clampf(.35 + .75 * (n.dot(light) * .5 + .5), 0.0, 1.2)
				var b := col.darkened(.25)
				img.set_pixel(x, y, Color(b.r * shade, b.g * shade, b.b * shade, 1.0))
			else:
				var along := (p - c).dot(dirv)
				var perp := absf((p - c).cross(dirv))
				if along > rad * .6 and along < rad * (1.0 + spur * 2.2) and perp < maxf(1.5, 4.0 * (1.0 - (along - rad) / (rad * 3.0))):
					img.set_pixel(x, y, col.lightened(.1))
	return ImageTexture.create_from_image(img)
