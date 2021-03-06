/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2018 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * An Email represents a single RFC 822 style email message.
 *
 * This class provides a common abstraction over different
 * representations of email messages, allowing messages from different
 * mail systems, from both local and remote sources, and locally
 * composed email messages to all be represented by a single
 * object. While this object represents a RFC 822 message, it also
 * holds additional metadata about an email not specified by that
 * format, such as its unique {@link id}, and unread state and other
 * {@link email_flags}.
 *
 * Email objects may by constructed in many ways, but are usually
 * obtained via a {@link Folder}. Email objects may be partial
 * representations of messages, in cases where a remote message has
 * not been fully downloaded, or a local message not fully loaded from
 * a database. This can be checked via an email's {@link fields}
 * property, and if the currently loaded fields are not sufficient,
 * then additional fields can be loaded via a folder.
 */
public class Geary.Email : BaseObject {

    /**
     * The maximum expected length of message body preview text.
     */
    public const int MAX_PREVIEW_BYTES = 256;

    /**
     * Indicates email fields that may change over time.
     *
     * Currently only one field is mutable: FLAGS. All others never
     * change once stored in the database.
     */
    public const Field MUTABLE_FIELDS = Geary.Email.Field.FLAGS;

    /**
     * Indicates the email fields required to build an RFC822.Message.
     *
     * @see get_message
     */
    public const Field REQUIRED_FOR_MESSAGE = Geary.Email.Field.HEADER | Geary.Email.Field.BODY;

    /**
     * Specifies specific parts of an email message.
     *
     * See the {@link Email.fields} property to determine which parts
     * an email object currently contains.
     */
    public enum Field {
        // THESE VALUES ARE PERSISTED.  Change them only if you know what you're doing.

        /** Denotes no fields. */
        NONE =              0,

        /** The RFC 822 Date header. */
        DATE =              1 << 0,

        /** The RFC 822 From, Sender, and Reply-To headers. */
        ORIGINATORS =       1 << 1,

        /** The RFC 822 To, Cc, and Bcc headers. */
        RECEIVERS =         1 << 2,

        /** The RFC 822 Message-Id, In-Reply-To, and References headers. */
        REFERENCES =        1 << 3,

        /** The RFC 822 Subject header. */
        SUBJECT =           1 << 4,

        /** The list of all RFC 822 headers. */
        HEADER =            1 << 5,

        /** The RFC 822 message body and attachments. */
        BODY =              1 << 6,

        /** The {@link Email.properties} object. */
        PROPERTIES =        1 << 7,

        /** The plain text preview. */
        PREVIEW =           1 << 8,

        /** The {@link Email.email_flags} object. */
        FLAGS =             1 << 9,

        /**
         * The union of the primary headers of a message.
         *
         * The envelope includes the {@link DATE}, {@link
         * ORIGINATORS}, {@link RECEIVERS}, {@link REFERENCES}, and
         * {@link SUBJECT} fields.
         */
        ENVELOPE = DATE | ORIGINATORS | RECEIVERS | REFERENCES | SUBJECT,

        /** The union of all email fields. */
        ALL =      DATE | ORIGINATORS | RECEIVERS | REFERENCES | SUBJECT |
                   HEADER | BODY | PROPERTIES | PREVIEW | FLAGS;

        public static Field[] all() {
            return {
                DATE,
                ORIGINATORS,
                RECEIVERS,
                REFERENCES,
                SUBJECT,
                HEADER,
                BODY,
                PROPERTIES,
                PREVIEW,
                FLAGS
            };
        }
        
        public inline bool is_all_set(Field required_fields) {
            return (this & required_fields) == required_fields;
        }
        
        public inline bool is_any_set(Field required_fields) {
            return (this & required_fields) != 0;
        }
        
        public inline Field set(Field field) {
            return (this | field);
        }
        
        public inline Field clear(Field field) {
            return (this & ~(field));
        }
        
        public inline bool fulfills(Field required_fields) {
            return is_all_set(required_fields);
        }
        
        public inline bool fulfills_any(Field required_fields) {
            return is_any_set(required_fields);
        }
        
        public inline bool require(Field required_fields) {
            return is_all_set(required_fields);
        }
        
        public inline bool requires_any(Field required_fields) {
            return is_any_set(required_fields);
        }
        
        public string to_list_string() {
            StringBuilder builder = new StringBuilder();
            foreach (Field f in all()) {
                if (is_all_set(f)) {
                    if (!String.is_empty(builder.str))
                        builder.append(", ");
                    
                    builder.append(f.to_string());
                }
            }
            
            return builder.str;
        }
    }

    /**
     * A unique identifier for the Email in the Folder.
     *
     * This is is guaranteed to be unique for as long as the Folder is
     * open. Once closed, guarantees are no longer made.
     *
     * This field is always returned, no matter what Fields are used
     * to retrieve the Email.
     */
    public Geary.EmailIdentifier id { get; private set; }

    // DATE
    public Geary.RFC822.Date? date { get; private set; default = null; }

    // ORIGINATORS
    public Geary.RFC822.MailboxAddresses? from { get; private set; default = null; }
    public Geary.RFC822.MailboxAddress? sender { get; private set; default = null; }
    public Geary.RFC822.MailboxAddresses? reply_to { get; private set; default = null; }

    // RECEIVERS
    public Geary.RFC822.MailboxAddresses? to { get; private set; default = null; }
    public Geary.RFC822.MailboxAddresses? cc { get; private set; default = null; }
    public Geary.RFC822.MailboxAddresses? bcc { get; private set; default = null; }
    
    // REFERENCES
    public Geary.RFC822.MessageID? message_id { get; private set; default = null; }
    public Geary.RFC822.MessageIDList? in_reply_to { get; private set; default = null; }
    public Geary.RFC822.MessageIDList? references { get; private set; default = null; }
    
    // SUBJECT
    public Geary.RFC822.Subject? subject { get; private set; default = null; }
    
    // HEADER
    public RFC822.Header? header { get; private set; default = null; }
    
    // BODY
    public RFC822.Text? body { get; private set; default = null; }
    public Gee.List<Geary.Attachment> attachments { get; private set;
        default = new Gee.ArrayList<Geary.Attachment>(); }
    
    // PROPERTIES
    public Geary.EmailProperties? properties { get; private set; default = null; }
    
    // PREVIEW
    public RFC822.PreviewText? preview { get; private set; default = null; }
    
    // FLAGS
    public Geary.EmailFlags? email_flags { get; private set; default = null; }

    /**
     * Specifies the properties that have been populated for this email.
     *
     * Since this email object may be a partial representation of a
     * complete email message, this property lists all parts of the
     * object that have actually been loaded, as opposed to parts that
     * are simply missing from the email it represents.
     *
     * For example, if this property includes the {@link
     * Field.SUBJECT} flag, then the {@link subject} property has been
     * set to reflect the Subject header of the message. Of course,
     * the subject may then still may be null or empty, if the email
     * did not specify a subject header.
     */
    public Geary.Email.Field fields { get; private set; default = Field.NONE; }

    private Geary.RFC822.Message? message = null;
    
    public Email(Geary.EmailIdentifier id) {
        this.id = id;
    }
    
    public inline Trillian is_unread() {
        return email_flags != null ? Trillian.from_boolean(email_flags.is_unread()) : Trillian.UNKNOWN;
    }

    public inline Trillian is_flagged() {
        return email_flags != null ? Trillian.from_boolean(email_flags.is_flagged()) : Trillian.UNKNOWN;
    }
    
    public inline Trillian load_remote_images() {
        return email_flags != null ? Trillian.from_boolean(email_flags.load_remote_images()) : Trillian.UNKNOWN;
    }

    public void set_send_date(Geary.RFC822.Date? date) {
        this.date = date;
        
        fields |= Field.DATE;
    }

    /**
     * Sets the RFC822 originators for the message.
     *
     * RFC 2822 requires at least one From address, that the Sender
     * and From not be identical, and that both From and ReplyTo are
     * optional.
     */
    public void set_originators(Geary.RFC822.MailboxAddresses? from,
                                Geary.RFC822.MailboxAddress? sender,
                                Geary.RFC822.MailboxAddresses? reply_to)
        throws RFC822Error {
        // XXX Should be throwing an error here if from is empty or
        // sender is same as from
        this.from = from;
        this.sender = sender;
        this.reply_to = reply_to;

        fields |= Field.ORIGINATORS;
    }

    public void set_receivers(Geary.RFC822.MailboxAddresses? to,
        Geary.RFC822.MailboxAddresses? cc, Geary.RFC822.MailboxAddresses? bcc) {
        this.to = to;
        this.cc = cc;
        this.bcc = bcc;
        
        fields |= Field.RECEIVERS;
    }
    
    public void set_full_references(Geary.RFC822.MessageID? message_id, Geary.RFC822.MessageIDList? in_reply_to,
        Geary.RFC822.MessageIDList? references) {
        this.message_id = message_id;
        this.in_reply_to = in_reply_to;
        this.references = references;
        
        fields |= Field.REFERENCES;
    }
    
    public void set_message_subject(Geary.RFC822.Subject? subject) {
        this.subject = subject;
        
        fields |= Field.SUBJECT;
    }
    
    public void set_message_header(Geary.RFC822.Header header) {
        this.header = header;
        
        // reset the message object, which is built from this text
        message = null;
        
        fields |= Field.HEADER;
    }
    
    public void set_message_body(Geary.RFC822.Text body) {
        this.body = body;
        
        // reset the message object, which is built from this text
        message = null;
        
        fields |= Field.BODY;
    }
    
    public void set_email_properties(Geary.EmailProperties properties) {
        this.properties = properties;
        
        fields |= Field.PROPERTIES;
    }
    
    public void set_message_preview(Geary.RFC822.PreviewText preview) {
        this.preview = preview;
        
        fields |= Field.PREVIEW;
    }

    public void set_flags(Geary.EmailFlags email_flags) {
        this.email_flags = email_flags;
        
        fields |= Field.FLAGS;
    }

    public void add_attachment(Geary.Attachment attachment) {
        attachments.add(attachment);
    }
    
    public void add_attachments(Gee.Collection<Geary.Attachment> attachments) {
        this.attachments.add_all(attachments);
    }
    
    public string get_searchable_attachment_list() {
        StringBuilder search = new StringBuilder();
        foreach (Geary.Attachment attachment in attachments) {
            if (attachment.has_content_filename) {
                search.append(attachment.content_filename);
                search.append("\n");
            }
        }
        return search.str;
    }

    /**
     * Constructs a new RFC 822 message from this email.
     *
     * This method requires the {@link REQUIRED_FOR_MESSAGE} fields be
     * present. If not, {@link EngineError.INCOMPLETE_MESSAGE} is
     * thrown.
     */
    public Geary.RFC822.Message get_message() throws EngineError, RFC822Error {
        if (message != null)
            return message;
        
        if (!fields.fulfills(REQUIRED_FOR_MESSAGE))
            throw new EngineError.INCOMPLETE_MESSAGE("Parsed email requires HEADER and BODY");
        
        message = new Geary.RFC822.Message.from_parts(header, body);
        
        return message;
    }

    /**
     * Returns the attachment with the given {@link Geary.Attachment.id}.
     *
     * Requires the REQUIRED_FOR_MESSAGE fields be present; else
     * EngineError.INCOMPLETE_MESSAGE is thrown.
     */
    public Geary.Attachment? get_attachment_by_id(string attachment_id)
    throws EngineError {
        if (!fields.fulfills(REQUIRED_FOR_MESSAGE))
            throw new EngineError.INCOMPLETE_MESSAGE("Parsed email requires HEADER and BODY");

        foreach (Geary.Attachment attachment in attachments) {
            if (attachment.id == attachment_id) {
                return attachment;
            }
        }
        return null;
    }

    /**
     * Returns the attachment with the given MIME Content ID.
     *
     * Requires the REQUIRED_FOR_MESSAGE fields be present; else
     * EngineError.INCOMPLETE_MESSAGE is thrown.
     */
    public Geary.Attachment? get_attachment_by_content_id(string cid)
    throws EngineError {
        if (!fields.fulfills(REQUIRED_FOR_MESSAGE))
            throw new EngineError.INCOMPLETE_MESSAGE("Parsed email requires HEADER and BODY");

        foreach (Geary.Attachment attachment in attachments) {
            if (attachment.content_id == cid) {
                return attachment;
            }
        }
        return null;
    }

    /**
     * Returns a list of this email's ancestry by Message-ID.  IDs are not returned in any
     * particular order.  The ancestry is made up from this email's Message-ID, its References,
     * and its In-Reply-To.  Thus, this email must have been fetched with Field.REFERENCES for
     * this method to return a complete list.
     */
    public Gee.Set<RFC822.MessageID>? get_ancestors() {
        Gee.Set<RFC822.MessageID> ancestors = new Gee.HashSet<RFC822.MessageID>();
        
        // the email's Message-ID counts as its lineage
        if (message_id != null)
            ancestors.add(message_id);
        
        // References list the email trail back to its source
        if (references != null)
            ancestors.add_all(references.list);
        
        // RFC822 requires the In-Reply-To Message-ID be prepended to the References list, but
        // this ensures that's the case
        if (in_reply_to != null)
           ancestors.add_all(in_reply_to.list);
       
       return (ancestors.size > 0) ? ancestors : null;
    }
    
    public string get_preview_as_string() {
        return (preview != null) ? preview.buffer.to_string() : "";
    }
    
    /**
     * Returns the primary originator of an email, which is defined as the first mailbox address
     * in From:, Sender:, or Reply-To:, in that order, depending on availability.
     *
     * Returns null if no originators are present.
     */
    public RFC822.MailboxAddress? get_primary_originator() {
        if (from != null && from.size > 0)
            return from[0];

        if (sender != null)
            return sender;

        if (reply_to != null && reply_to.size > 0)
            return reply_to[0];

        return null;
    }

    public string to_string() {
        return "[%s] ".printf(id.to_string());
    }
    
    /**
     * Converts a Collection of {@link Email}s to a Map of Emails keyed by {@link EmailIdentifier}s.
     *
     * @return null if emails is empty or null.
     */
    public static Gee.Map<Geary.EmailIdentifier, Geary.Email>? emails_to_map(Gee.Collection<Geary.Email>? emails) {
        if (emails == null || emails.size == 0)
            return null;
        
        Gee.Map<Geary.EmailIdentifier, Geary.Email> map = new Gee.HashMap<Geary.EmailIdentifier,
            Geary.Email>();
        foreach (Email email in emails)
            map.set(email.id, email);
        
        return map;
    }
    
    /**
     * CompareFunc to sort {@link Email} by {@link date} ascending.
     *
     * If the date field is unavailable on either Email, their identifiers are compared to
     * stabilize the sort.
     */
    public static int compare_sent_date_ascending(Geary.Email aemail, Geary.Email bemail) {
        if (aemail.date == null || bemail.date == null) {
            GLib.message("Warning: comparing email for sent date but no Date: field loaded");
            
            return compare_id_ascending(aemail, bemail);
        }
        
        int compare = aemail.date.value.compare(bemail.date.value);
        
        // stabilize sort by using the mail identifier's stable sort ordering
        return (compare != 0) ? compare : compare_id_ascending(aemail, bemail);
    }
    
    /**
     * CompareFunc to sort {@link Email} by {@link date} descending.
     *
     * If the date field is unavailable on either Email, their identifiers are compared to
     * stabilize the sort.
     */
    public static int compare_sent_date_descending(Geary.Email aemail, Geary.Email bemail) {
        return compare_sent_date_ascending(bemail, aemail);
    }
    
    /**
     * CompareFunc to sort {@link Email} by {@link EmailProperties.date_received} ascending.
     *
     * If {@link properties} is unavailable on either Email, their identifiers are compared to
     * stabilize the sort.
     */
    public static int compare_recv_date_ascending(Geary.Email aemail, Geary.Email bemail) {
        if (aemail.properties == null || bemail.properties == null) {
            GLib.message("Warning: comparing email for received date but email properties not loaded");
            
            return compare_id_ascending(aemail, bemail);
        }
        
        int compare = aemail.properties.date_received.compare(bemail.properties.date_received);
        
        // stabilize sort with identifiers
        return (compare != 0) ? compare : compare_id_ascending(aemail, bemail);
    }
    
    /**
     * CompareFunc to sort {@link Email} by {@link EmailProperties.date_received} descending.
     *
     * If {@link properties} is unavailable on either Email, their identifiers are compared to
     * stabilize the sort.
     */
    public static int compare_recv_date_descending(Geary.Email aemail, Geary.Email bemail) {
        return compare_recv_date_ascending(bemail, aemail);
    }
    
    // only used to stabilize a sort
    private static int compare_id_ascending(Geary.Email aemail, Geary.Email bemail) {
        return aemail.id.stable_sort_comparator(bemail.id);
    }
    
    /**
     * CompareFunc to sort Email by EmailProperties.total_bytes.  If not available, emails are
     * compared by EmailIdentifier.
     */
    public static int compare_size_ascending(Geary.Email aemail, Geary.Email bemail) {
        Geary.EmailProperties? aprop = (Geary.EmailProperties) aemail.properties;
        Geary.EmailProperties? bprop = (Geary.EmailProperties) bemail.properties;
        
        if (aprop == null || bprop == null) {
            GLib.message("Warning: comparing email by size but email properties not loaded");
            
            return compare_id_ascending(aemail, bemail);
        }
        
        int cmp = (int) (aprop.total_bytes - bprop.total_bytes).clamp(-1, 1);
        
        return (cmp != 0) ? cmp : compare_id_ascending(aemail, bemail);
    }
    
    /**
     * CompareFunc to sort Email by EmailProperties.total_bytes.  If not available, emails are
     * compared by EmailIdentifier.
     */
    public static int compare_size_descending(Geary.Email aemail, Geary.Email bemail) {
        return compare_size_ascending(bemail, aemail);
    }
}

