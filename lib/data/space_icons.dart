/// Icon choices offered in the "New space" / "Edit space" dialogs.
///
/// Grouped roughly by theme so the source stays readable. The dialog
/// renders them flat — the grouping is a maintenance aid, not a UI
/// structure. Emojis that need a variation selector (e.g. `🗂️`, `☀️`,
/// `❤️`) include one so they render as emoji rather than text glyphs on
/// all platforms.
const List<String> kSpaceIcons = [
  // Notes, books, writing
  '📓', '📔', '📕', '📗', '📘', '📙', '📚', '📖',
  '📝', '✏️', '📄', '📋', '📰',

  // Bookmarks, markers, organization
  '🔖', '🏷️', '📌', '📍', '🗂️', '🗃️',

  // Ideas, planning, navigation
  '💡', '🧠', '🎯', '🧭', '🗺️',

  // Nature, growth
  '🌱', '🌿', '🌳', '🌸', '🍀', '🌈', '🌍',

  // Energy, cosmos
  '☀️', '🌙', '⭐', '✨', '⚡', '🔥',

  // Work, tech, tools
  '💼', '💻', '🖥️', '📱', '⚙️', '🔧', '🛠️',

  // Science, learning
  '🔬', '🧪', '🔭', '🎓',

  // Creative, arts, media
  '🎨', '🖌️', '🎭', '🎬', '🎵', '🎧', '📷',

  // Money, finance
  '💰', '💵', '💳', '📈',

  // Personal, home, life
  '❤️', '🏠', '🏢', '🛒', '🍳', '☕',

  // Travel, places
  '✈️', '🚀', '🏖️', '🏔️',

  // Fun, misc
  '🎮', '🎲', '🎁', '🏆', '🔑', '🛡️', '🧩',
];