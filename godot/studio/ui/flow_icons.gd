extends RefCounted
## Small, consistent outline icons; textures are generated locally, no imported assets.
static func make(id: String) -> ImageTexture:
	var paths := {
		"back": '<path d="M14 5l-7 7 7 7M7 12h14"/>',
		"build": '<path d="M5 19l3-7 9-9 4 4-9 9zM8 12l4 4M15 5l4 4"/>',
		"paint": '<path d="M14 4l6 6-8 8-6-6zM4 16c-3 5 1 6 4 4l2-2"/>',
		"test": '<path d="M8 4l12 8-12 8z"/>',
		"undo": '<path d="M9 4L3 10l6 6M3 10h10a7 7 0 017 7"/>',
		"redo": '<path d="M15 4l6 6-6 6M21 10h-10a7 7 0 00-7 7"/>',
		"file": '<path d="M4 5h6l2 3h8v12H4z"/>',
		"details": '<path d="M4 6h16M4 12h16M4 18h16"/><circle cx="9" cy="6" r="2"/><circle cx="15" cy="12" r="2"/><circle cx="9" cy="18" r="2"/>',
		"help": '<circle cx="12" cy="12" r="9"/><path d="M9 9a3 3 0 016 0c0 2-3 2-3 5M12 17v.2"/>',
	}
	var img := Image.new()
	img.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#f2f6f4" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' + paths.get(id, paths.details) + '</g></svg>')
	return ImageTexture.create_from_image(img)
