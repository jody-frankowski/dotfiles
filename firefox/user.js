// Disable url bar result menu button
// https://bugzilla.mozilla.org/show_bug.cgi?id=1813517
user_pref("browser.urlbar.resultMenu.keyboardAccessible", false);

// --- Disable AI Features ---
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.page.footerBadge", false);
user_pref("browser.ml.chat.page.menuBadge", false);
user_pref("browser.ml.chat.shortcuts", false);
user_pref("browser.ml.chat.shortcuts.custom", false);
user_pref("browser.ml.chat.sidebar", false);
user_pref("browser.ml.checkForMemory", false);
user_pref("browser.ml.enable", false);
user_pref("browser.ml.linkPreview.shift", false);
// Remove the "Ask an AI Chatbot" button
user_pref("browser.ml.chat.menu", false);
// Disable Link Previews (and the AI-generated key points inside them)
user_pref("browser.ml.linkPreview.enabled", false);

// --- Context Menu & UI Clutter Cleanup ---
// https://joshua.hu/firefox-making-right-click-not-suck
// https://joshua.hu/firefox-making-right-click-not-suck-even-more-with-userchrome
// Remove the "Translate Selection" button from the right-click menu
user_pref("browser.translations.select.enable", false);
// Disable the built-in Firefox screenshot functionality ("Take Screenshot" button)
user_pref("screenshots.browser.component.enabled", false);
// Disable Text Fragments support ("Copy Link to Highlight" button)
user_pref("dom.text_fragments.enabled", false);
// Disable the DevTools Accessibility Inspector ("Inspect Accessibility Properties" button)
user_pref("devtools.accessibility.enabled", false);
// Disable OCR on images ("Copy Text From Image" button)
user_pref("dom.text-recognition.enabled", false);
// Disable Visual Search (Google Lens integration)
user_pref("browser.search.visualSearch.featureGate", false);
// Turn off native macOS context menus for Firefox to use its own menus (removes "Services")
user_pref("widget.macos.native-context-menus", false);
// Enable chrome/user{Chrome,Content}.css support
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
