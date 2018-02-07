/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2016 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/**
 * A WebView for editing messages in the composer.
 */
public class ComposerWebView : ClientWebView {


    private const string COMMAND_STACK_CHANGED = "commandStackChanged";
    private const string CURSOR_CONTEXT_CHANGED = "cursorContextChanged";
    private const string DOCUMENT_MODIFIED = "documentModified";

    /**
     * Encapsulates editing-related state for a specific DOM node.
     *
     * This must be kept in sync with the JS object of the same name.
     */
    public class EditContext : Object {

        private const uint LINK_MASK = 1 << 0;

        private const string[] SANS_FAMILY_NAMES = {
            "sans", "arial", "trebuchet", "helvetica"
        };
        private const string[] SERIF_FAMILY_NAMES = {
            "serif", "georgia", "times"
        };
        private const string[] MONO_FAMILY_NAMES = {
            "monospace", "courier", "console"
        };

        private static Gee.HashMap<string,string> font_family_map =
            new Gee.HashMap<string,string>();

        static construct {
            foreach (string name in SANS_FAMILY_NAMES) {
                font_family_map[name] = "sans";
            }
            foreach (string name in SERIF_FAMILY_NAMES) {
                font_family_map[name] = "serif";
            }
            foreach (string name in MONO_FAMILY_NAMES) {
                font_family_map[name] = "monospace";
            }
        }


        public bool is_link { get { return (this.context & LINK_MASK) > 0; } }
        public string link_url { get; private set; default = ""; }
        public string font_family { get; private set; default = "sans"; }
        public uint font_size { get; private set; default = 12; }

        private uint context = 0;

        public EditContext(string message) {
            string[] values = message.split(",");
            this.context = (uint) uint64.parse(values[0]);

            this.link_url = values[1];

            string view_name = values[2].down();
            foreach (string specific_name in EditContext.font_family_map.keys) {
                if (specific_name in view_name) {
                    this.font_family = EditContext.font_family_map[specific_name];
                    break;
                }
            }

            this.font_size = (uint) uint64.parse(values[3]);
        }

    }


    private static WebKit.UserStyleSheet? app_style = null;
    private static WebKit.UserScript? app_script = null;

    public static void load_resources()
        throws Error {
        ComposerWebView.app_style = ClientWebView.load_app_stylesheet(
            "composer-web-view.css"
        );
        ComposerWebView.app_script = ClientWebView.load_app_script(
            "composer-web-view.js"
        );
    }

    /**
     * Determines if the body contains any non-boilerplate content.
     *
     * Currently, only a signatures are considered to be boilerplate.
     * Any user-made changes or message body content from a
     * forwarded/replied-to message present will make the view
     * considered to be non-empty.
     */
    public bool is_empty { get; private set; default = true; }

    /** Determines if the view is in rich text mode. */
    public bool is_rich_text { get; private set; default = true; }

    // Determines if signals should be sent, useful for e.g. stopping
    // document_modified being sent when the editor content is being
    // updated before sending.
    private bool signals_enabled = true;


    /** Emitted when the web view's content has changed. */
    public signal void document_modified();

    /** Emitted when the web view's undo/redo stack state changes. */
    public signal void command_stack_changed(bool can_undo, bool can_redo);

    /** Emitted when the cursor's edit context has changed. */
    public signal void cursor_context_changed(EditContext cursor_context);

    /** Workaround for WebView eating the button event */
    internal signal bool button_release_event_done(Gdk.Event event);


    public ComposerWebView(Configuration config) {
        base(config);

        add_events(Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);

        this.user_content_manager.add_style_sheet(ComposerWebView.app_style);
        this.user_content_manager.add_script(ComposerWebView.app_script);

        register_message_handler(COMMAND_STACK_CHANGED, on_command_stack_changed);
        register_message_handler(CURSOR_CONTEXT_CHANGED, on_cursor_context_changed);
        register_message_handler(DOCUMENT_MODIFIED, on_document_modified);
    }

    /**
     * Loads a message HTML body into the view.
     */
    public new void load_html(string body,
                              string signature,
                              string quote,
                              bool top_posting,
                              bool is_draft) {
        const string HTML_PRE = """<html><body class="%s" dir="auto">""";
        const string HTML_POST = """</body></html>""";
        const string BODY_PRE = """
<div id="geary-body">""";
        const string BODY_POST = """</div>
""";
        const string SIGNATURE = """
<div id="geary-signature">%s</div>
""";
        const string QUOTE = """
<div id="geary-quote"><br />%s</div>
""";
        const string CURSOR = "<div><span id=\"cursormarker\"></span><br /></div>";
        const string SPACER = "<div><br /></div>";

        StringBuilder html = new StringBuilder();
        string body_class = (this.is_rich_text) ? "" : "plain";
        html.append(HTML_PRE.printf(body_class));
        if (!is_draft) {
            html.append(BODY_PRE);
            bool have_body = !Geary.String.is_empty(body);
            if (have_body) {
                html.append(body);
                html.append(SPACER);
            }

            if (!top_posting && !Geary.String.is_empty(quote)) {
                html.append(quote);
                html.append(SPACER);
            }

            html.append(CURSOR);
            html.append(BODY_POST);

            if (!Geary.String.is_empty(signature)) {
                html.append_printf(SIGNATURE, signature);
            }

            if (top_posting && !Geary.String.is_empty(quote)) {
                html.append_printf(QUOTE, quote);
            }
        } else {
            html.append(quote);
        }
        html.append(HTML_POST);
        base.load_html((string) html.data);
    }

    /**
     * Makes the view uneditable and stops signals from being sent.
     */
    public void disable() {
        set_sensitive(false);
        this.signals_enabled = false;
    }

    /**
     * Sets whether the editor is in rich text or plain text mode.
     */
    public void set_rich_text(bool enabled) {
        this.is_rich_text = enabled;
        if (this.is_content_loaded) {
            this.call.begin(Geary.JS.callable("geary.setRichText").bool(enabled), null);
        }
    }

    /**
     * Undoes the last edit operation.
     */
    public void undo() {
        this.call.begin(Geary.JS.callable("geary.undo"), null);
    }

    /**
     * Redoes the last undone edit operation.
     */
    public void redo() {
        this.call.begin(Geary.JS.callable("geary.redo"), null);
    }

    /**
     * Saves the current text selection so it can be restored later.
     *
     * Returns an id to be used to refer to the selection in
     * subsequent calls.
     */
    public async string save_selection() throws Error {
        return WebKitUtil.to_string(
            yield call(Geary.JS.callable("geary.saveSelection"), null)
        );
    }

    /**
     * Removes a saved selection.
     */
    public void free_selection(string id) {
        this.call.begin(Geary.JS.callable("geary.freeSelection").string(id), null);
    }

    /**
     * Cuts selected content and sends it to the clipboard.
     */
    public void cut_clipboard() {
        execute_editing_command(WebKit.EDITING_COMMAND_CUT);
    }

    /**
     * Pastes plain text from the clipboard into the view.
     */
    public void paste_plain_text() {
        get_clipboard(Gdk.SELECTION_CLIPBOARD).request_text((clipboard, text) => {
                if (text != null) {
                    insert_text(text);
                }
            });
    }

    /**
     * Pastes rich text from the clipboard into the view.
     */
    public void paste_rich_text() {
        execute_editing_command(WebKit.EDITING_COMMAND_PASTE);
    }

    /**
     * Inserts some text at the current text cursor location.
     */
    public void insert_text(string text) {
        execute_editing_command_with_argument("inserttext", text);

        // XXX scroll to insertion point:

        // The inserttext command will not scroll if needed, but we
        // can't use the clipboard for plain text. WebKit allows us to
        // scroll a node into view, but not an arbitrary position
        // within a text node. So we add a placeholder node at the
        // cursor position, scroll to that, then remove the
        // placeholder node.
        // try {
        //     WebKit.DOM.DOMSelection selection = document.default_view.get_selection();
        //     WebKit.DOM.Node selection_base_node = selection.get_base_node();
        //     long selection_base_offset = selection.get_base_offset();

        //     WebKit.DOM.NodeList selection_child_nodes = selection_base_node.get_child_nodes();
        //     WebKit.DOM.Node ref_child = selection_child_nodes.item(selection_base_offset);

        //     WebKit.DOM.Element placeholder = document.create_element("SPAN");
        //     WebKit.DOM.Text placeholder_text = document.create_text_node("placeholder");
        //     placeholder.append_child(placeholder_text);

        //     if (selection_base_node.node_name == "#text") {
        //         WebKit.DOM.Node? left = get_left_text(selection_base_node, selection_base_offset);

        //         WebKit.DOM.Node parent = selection_base_node.parent_node;
        //         if (left != null)
        //             parent.insert_before(left, selection_base_node);
        //         parent.insert_before(placeholder, selection_base_node);
        //         parent.remove_child(selection_base_node);

        //         placeholder.scroll_into_view_if_needed(false);
        //         parent.insert_before(selection_base_node, placeholder);
        //         if (left != null)
        //             parent.remove_child(left);
        //         parent.remove_child(placeholder);
        //         selection.set_base_and_extent(selection_base_node, selection_base_offset, selection_base_node, selection_base_offset);
        //     } else {
        //         selection_base_node.insert_before(placeholder, ref_child);
        //         placeholder.scroll_into_view_if_needed(false);
        //         selection_base_node.remove_child(placeholder);
        //     }
        // } catch (Error err) {
        //     debug("Error scrolling pasted text into view: %s", err.message);
        // }
    }

    // private WebKit.DOM.Node? get_left_text(WebKit.WebPage page, WebKit.DOM.Node node, long offset) {
    //     WebKit.DOM.Document document = page.get_dom_document();
    //     string node_value = node.node_value;

    //     // Offset is in unicode characters, but index is in bytes. We need to get the corresponding
    //     // byte index for the given offset.
    //     int char_count = node_value.char_count();
    //     int index = offset > char_count ? node_value.length : node_value.index_of_nth_char(offset);

    //     return offset > 0 ? document.create_text_node(node_value[0:index]) : null;
    // }

    /**
     * Inserts some HTML at the current text cursor location.
     */
    public void insert_html(string markup) {
        execute_editing_command_with_argument("insertHTML", markup);
    }

    /**
     * Inserts or updates an A element at the current text cursor location.
     *
     * If the cursor is located on an A element, the element's HREF
     * will be updated, else if some text is selected, an A element
     * will be inserted wrapping the selection.
     */
    public void insert_link(string href, string selection_id) {
        this.call.begin(
            Geary.JS.callable("geary.insertLink").string(href).string(selection_id),
            null
        );
    }

    /**
     * Removes any A element at the current text cursor location.
     */
    public void delete_link() {
        this.call.begin(Geary.JS.callable("geary.deleteLink"), null);
    }

    /**
     * Inserts an IMG element at the current text cursor location.
     */
    public void insert_image(string src) {
        // Use insertHTML instead of insertImage here so
        // we can specify a max width inline, preventing
        // large images from overflowing the view port.
        execute_editing_command_with_argument(
            "insertHTML",
            @"<img style=\"max-width: 100%\" src=\"$src\">"
        );
    }

    /**
     * Indents the line at the current text cursor location.
     */
    public void indent_line() {
        this.call.begin(Geary.JS.callable("geary.indentLine"), null);
    }

    public void insert_olist() {
	this.call.begin(Geary.JS.callable("geary.insertOrderedList"), null);
    }

    public void insert_ulist() {
	this.call.begin(Geary.JS.callable("geary.insertUnorderedList"), null);
    }

    /**
     * Updates the signature block if it has not been deleted.
     */
    public new void update_signature(string signature) {
        this.call.begin(Geary.JS.callable("geary.updateSignature").string(signature), null);
    }

    /**
     * Removes the quoted message (if any) from the composer.
     */
    public void delete_quoted_message() {
        this.call.begin(Geary.JS.callable("geary.deleteQuotedMessage"), null);
    }

    /**
     * Determines if the editor content contains an attachment keyword.
     */
    public async bool contains_attachment_keywords(string keyword_spec, string subject) {
        try {
            return WebKitUtil.to_bool(
                yield call(
                    Geary.JS.callable("geary.containsAttachmentKeyword")
                    .string(keyword_spec)
                    .string(subject),
                    null)
                );
        } catch (Error err) {
            debug("Error checking or attchment keywords: %s", err.message);
            return false;
        }
    }

    /**
     * Cleans the editor content ready for sending.
     *
     * This modifies the DOM, so there's no going back after calling
     * this.
     */
    public async void clean_content() throws Error {
        this.call.begin(Geary.JS.callable("geary.cleanContent"), null);
    }

    /**
     * Returns the editor content as an HTML string.
     */
    public async string? get_html() throws Error {
        return WebKitUtil.to_string(
            yield call(Geary.JS.callable("geary.getHtml"), null)
        );
    }

    /**
     * Returns the editor text as RFC 3676 format=flowed text.
     */
    public async string? get_text() throws Error {
        const int MAX_BREAKABLE_LEN = 72; // F=F recommended line limit
        const int MAX_UNBREAKABLE_LEN = 998; // SMTP line limit

        string body_text = WebKitUtil.to_string(
            yield call(Geary.JS.callable("geary.getText"), null)
        );
        string[] lines = body_text.split("\n");
        GLib.StringBuilder flowed = new GLib.StringBuilder.sized(body_text.length);
        foreach (string line in lines) {
            // Strip trailing whitespace, so it doesn't look like a
            // flowed line.  But the signature separator "-- " is
            // special, so leave that alone.
            if (line != "-- ")
                line = line.chomp();

            // Determine quoting depth by counting the the number of
            // QUOTE_MARKERs present, and build a quote prefix for it.
            int quote_level = 0;
            while (line[quote_level] == Geary.RFC822.Utils.QUOTE_MARKER)
                quote_level += 1;
            line = line[quote_level:line.length];
            string prefix = quote_level > 0 ? string.nfill(quote_level, '>') + " " : "";

            // Check to see if the line (with quote prefix) is longer
            // than the recommended limit, if so work out where to do
            int max_breakable = MAX_BREAKABLE_LEN - prefix.length;
            int max_unbreakable = MAX_UNBREAKABLE_LEN - prefix.length;
            do {
                int start_ind = 0;

                // Space stuff if needed
                if (quote_level == 0 &&
                    (line.has_prefix(">") || line.has_prefix("From"))) {
                    line = " " + line;
                    start_ind = 1;
                }

                // Check to see if we need to break the line, if so
                // determine where to do it.
                int cut_ind = line.length;
                if (cut_ind > max_breakable) {
                    // Line needs to be broken, look for the last
                    // useful place to break before before the
                    // max recommended length.
                    string beg = line[0:max_breakable];
                    cut_ind = beg.last_index_of(" ", start_ind) + 1;
                    if (cut_ind == 0) {
                        // No natural places to break found, so look
                        // for place further along, and if that is
                        // also not found then break on the SMTP max
                        // line length.
                        cut_ind = line.index_of(" ", start_ind) + 1;
                        if (cut_ind == 0)
                            cut_ind = line.length;
                        if (cut_ind > max_unbreakable)
                            cut_ind = max_unbreakable;
                    }
                }

                // Actually break the line
                flowed.append(prefix + line[0:cut_ind] + "\n");
                line = line[cut_ind:line.length];
            } while (line.length > 0);
        }

        return flowed.str;
    }

    public override bool button_release_event(Gdk.EventButton event) {
        // WebView seems to unconditionally consume button events, so
        // to show a link popopver after the view has processed one,
        // we need to emit our own.
        bool ret = base.button_release_event(event);
        if (this.signals_enabled) {
            button_release_event_done(event);
        }
        return ret;
    }

    private void on_command_stack_changed(WebKit.JavascriptResult result) {
        try {
            if (this.signals_enabled) {
                string[] values = WebKitUtil.to_string(result).split(",");
                command_stack_changed(values[0] == "true", values[1] == "true");
            }
        } catch (Geary.JS.Error err) {
            debug("Could not get command stack state: %s", err.message);
        }
    }

    private void on_cursor_context_changed(WebKit.JavascriptResult result) {
        try {
            if (this.signals_enabled) {
                cursor_context_changed(new EditContext(WebKitUtil.to_string(result)));
            }
        } catch (Geary.JS.Error err) {
            debug("Could not get text cursor style: %s", err.message);
        }
    }

    private void on_document_modified(WebKit.JavascriptResult result) {
        // Only modify actually changed to avoid excessive notify
        // signals being fired.
        if (this.signals_enabled) {
            if (this.is_empty) {
                this.is_empty = false;
            }
            document_modified();
        }
    }
}
