// Lyrics-Buddy: tools to insert and format lyrics
//
// Copyright (C) 2026 John Hartman
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import MuseScore
import Muse.UiComponents

// For debug dump until console is fixed
import FileIO

MuseScore {
    version: "1.0.0"
    title: "Lyrics-Buddy"
    description: "Tools to insert and format lyrics"
    // categoryCode: "composing-arranging-tools"
    pluginType: "dialog"
    thumbnailName: "lyrics-buddy.png"

    width:  800
    height: 200

    //============================================================================
    // Logging
    // Yes, this stuff should probably be a class in its on qml file
    property string  m_logString: ""
    property int     m_nestLevel: 0

    function init_log()
    {
        m_logString = "";
        m_nestLevel = 0;
    }

    function log(a_string)
    {
        if ((m_logString == "") || m_logString.endsWith("\n")) {
            // Start of a new line: indent
            m_logString += "   ".repeat(m_nestLevel);
        }

        m_logString += a_string;
    }

    // Write a timestamp and title (not indented)
    function time_stamp(a_string)
    {
        var date = new Date().toLocaleString();
        m_logString += "\n" + date + "\n" + a_string + "\n";
    }

    function write_file()
    {
        logFile.write(m_logString);
    }

    function up_nest(a_caption)
    {
        if (a_caption) {
            log(a_caption + "\n");
        }
        m_nestLevel += 1;
    }

    function down_nest()
    {
        if (m_nestLevel > 0) {
            m_nestLevel -= 1;
        }
    }

    //============================================================================
    // Return pitch integer as a string
    function pitchName( a_pitch )
    {
        var notes = [ "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" ];
        return notes[ a_pitch % 12 ] + (Math.floor(a_pitch / 12) - 1);
    }

    //============================================================================
    // Wrap an action in try/catch to ease debugging in the absence of console.log()
    function try_it( a_function, a_argument )
    {
        try {
            a_function(a_argument);
        } catch (error) {
            var str = error.message + "\n";
            if (error.qmlErrors) {
                // Google shows this, but I have yet to see it.
                // If I run Google's sample invocations, I get the basic error.message
                for (var i = 0; i < error.qmlErrors.length; i++) {
                    str += "File: " + error.qmlErrors[i].fileName + "\n";
                    str += "Line: " + error.qmlErrors[i].lineNumber + "\n";
                    str += "Message: " + error.qmlErrors[i].message + "\n\n";
                }
            }
            if (error.stackTrace) {
                // Google shows this, but I have yet to see it.
                str += error.stackTrace + "\n";
            }

            str += "File and line info may be found in MuseScore logfile.";
            message("Exception caught", str);

            // Rethrow, so file and line number info are logged
            throw error;
        }
    }

    //============================================================================
    onRun: {
        if (!curScore) {
            message("Error", "No score open.\nThis plugin requires an open score to run.\n");
            quit();
        }

        // Start the log
        init_log();
        time_stamp(title + " " + version);
    }

    //============================================================================
    // Change barline style
    function setBarlineStyle(a_style)
    {
        time_stamp("Setting barline style to " + a_style);

        var cursor = curScore.newCursor();
        cursor.InputStateMode = Cursor.INPUT_STATE_SYNC_WITH_SCORE;
        cursor.rewind(Cursor.SELECTION_END);
        var endTick = cursor.tick;
        if (endTick == 0) {
            // If SELECTION_END is the end of the score, cursor.tick is 0 (grrr!)
            endTick = curScore.lastSegment.tick;
        }

        cursor.rewind(Cursor.SELECTION_START);
        log("Selection is from tick " + cursor.tick + " to " + endTick + "\n");

        // Loop on segments to replace barlines
        curScore.startCmd();
        var segment = cursor.segment
        while (segment && (segment.tick <= endTick)) {
            up_nest("\nSegment at " + segment.tick);
            var element = segment.elementAt(cursor.track);
            if (element) {
                if (element.type === Element.BAR_LINE) {
                    log("Element is " + element.name + "\n");
                    showGoodStuff("barlineType", element.barlineType, "  ");
                    showGoodStuff("barlineSpan", element.barlineSpan, "  ");
                    showGoodStuff("barlineSpanFrom", element.barlineSpanFrom, "  ");
                    showGoodStuff("barlineSpanTo",   element.barlineSpanTo, "\n");

                    // Values from MuseScore src/engraving/dom/barline.h
                    // BARLINE_SPAN_TICK1_FROM        = -1;
                    // BARLINE_SPAN_TICK1_TO          = -7;
                    // BARLINE_SPAN_TICK2_FROM        = -2;
                    // BARLINE_SPAN_TICK2_TO          = -6;
                    // BARLINE_SPAN_SHORT1_FROM       =  2;
                    // BARLINE_SPAN_SHORT1_TO         = -2;
                    // BARLINE_SPAN_SHORT2_FROM       =  1;
                    // BARLINE_SPAN_SHORT2_TO         = -1;
                    switch (a_style) {
                        case "standard":
                            element.barlineSpan = true;
                            element.barlineSpanFrom = 0;
                            element.barlineSpanTo   = 0;
                            break;
                        case "tick1":
                            element.barlineSpan = false;
                            element.barlineSpanFrom = -1;
                            element.barlineSpanTo   = -7;
                            break;
                        case "short1":
                            element.barlineSpan = false;
                            element.barlineSpanFrom = 2;
                            element.barlineSpanTo   = -2;
                            break;
                        default:
                            message("Error", "Invalid barline style: " + a_style);
                            break;
                    }
                }
            }
            down_nest();
            segment = segment.next;
        }

        curScore.endCmd();
    }

    //============================================================================
    function chantify()
    {
        if (curScore.selection.elements.length == 0)
        {
            message("Error", "You must select a region to format.");
            return;
        }

        var barType = barlineType.model[barlineType.currentIndex].type;
        if (barType != "unchanged") {
            setBarlineStyle(barType);
        }

        var stem_type = stemType.model[stemType.currentIndex].type;
        if (stem_type != "unchanged") {
            time_stamp("Setting stems to " + stem_type);

            var cursor = curScore.newCursor();
            cursor.InputStateMode = Cursor.INPUT_STATE_SYNC_WITH_SCORE;
            cursor.rewind(Cursor.SELECTION_END);
            var endTick = cursor.tick;
            if (endTick == 0) {
                // If SELECTION_END is the end of the score, cursor.tick is 0 (grrr!)
                endTick = curScore.lastSegment.tick;
            }

            cursor.rewind(Cursor.SELECTION_START);
            log("Selection is from tick " + cursor.tick + " to " + endTick + "\n");

            curScore.startCmd();
            while (cursor.tick < endTick) {
                if (cursor.element.name == "Chord") {
                    log("Chord at " + cursor.tick + "\n");
                    //dumpObject( cursor.element, true );
                    log("  stem "    + (cursor.element.stem != null) + "\n");
                    log("  noStem "  + cursor.element.stem + "\n");

                    switch (stem_type) {
                        case "none":
                            cursor.element.noStem = true;
                            log("  Removed stem\n");
                            break;
                        case "standard":
                            cursor.element.noStem = false;
                            log("  Added stem\n");
                            break;
                        default:
                            message("Error", "Invalid stem style: " + stem_type);
                            break;
                    }
                }
                cursor.next();
            }

            curScore.endCmd();
        }
        write_file();
    }

    //============================================================================
    // Return the next word, syllable, or {group} from the input text.
    // Returns null if there is no more text
    function getSyllable()
    {
        var text = lyricText.text;

        // Test for bracketed {chant text} followed by space or hyphen
        // [0] gets matched portion string
        // [1] gets text inside the brackets
        // [2] gets hyphen, space, or empty string
        var tokens = text.match( /^\s*\{(.+)\}([ -]{0,1})/ );
        if (!tokens) {
            // Test for word or syllable followed by space or hyphen
            // [0] gets matched portion string
            // [1] gets text
            // [2] gets hyphen, space, or empty string
            tokens = text.match( /^\s*([^- \n]+)([ -]{0,1})/ );
        }

        if (tokens) {
            log("[0]='" + tokens[0] + "'\n");
            log("[1]='" + tokens[1] + "'\n");
            log("[2]='" + tokens[2] + "'\n");
            lyricText.text = text.slice(tokens[0].length).trim();
        }
        return tokens;
    }

    //============================================================================
    // If a_mode is "insert", insert a syllable or word, then advance selection
    // to the next note. Else advance selection without inserting.
    function insertLyric( a_mode )
    {
        if (curScore.selection.elements.length == 0)
        {
            message("Error", "You must select a location at which to add a lyric");
            return;
        }

        time_stamp("Processing Lyric " + a_mode);

        var verse = Number(verseNumber.value) - 1;

        curScore.startCmd();
        for (var ix=0; ix < curScore.selection.elements.length; ix++) {
            var chord = null;
            var element = curScore.selection.elements[ix];
            if (element.type == Element.CHORD) {
                chord = element;
            }
            else if (element.type == Element.NOTE) {
                chord = element.parent;
            }

            if (chord && (chord.type == Element.CHORD)) {
                var track = chord.track;

                if (a_mode == "insert") {
                    // Insert a word or syllable on this chord
                    var nVerses = chord.lyrics.length;
                    for (var vx = 0; vx < nVerses; vx++) {
                        if (chord.lyrics[vx].verse == verse) {
                            var str = 'This note already has lyric "' +
                                       chord.lyrics[vx].text + '" for verse ' +
                                       (verse+1);
                            message("Error", str);
                            return;
                        }
                    }

                    var tokens = getSyllable();
                    if (tokens) {
                        var lyrics = newElement(Element.LYRICS);
                        lyrics.text = tokens[1];
                        var str = 'Inserted "' + tokens[1] + '"';
                        lyrics.autoplace = true;
                        lyrics.subType = verse;
                        lyrics.verse = verse;
                        if (tokens[2] == '-') {
                            lyrics.syllabic = 1; // Syllabic.BEGIN;
                            str += ", hyphenated";
                        }

                        var leftOverage = lyrics.bbox.width/2 - Number(lyricLeftMax.text);
                        if (leftOverage > 0) {
                            // Centered lyric would extend too far left
                            lyrics.offsetX = leftOverage;
                            str += ", shifted right by " + leftOverage.toFixed(2);
                        }

                        chord.add(lyrics);
                        // dumpObject( chord, true );
                        log(str + "\n");
                    }
                }

                // Look for the next segment with a Chord in our voice/track
                var segment = chord.parent;
                while (segment.next) {
                    segment = segment.next;
                    chord = segment.elementAt(track);
                    if (chord && (chord.type == Element.CHORD)) {
                        log("Chord has " + chord.notes.length + " notes\n");
                        var note = chord.notes[0];
                        if (note) {
                            var ok = curScore.selection.select(note);
                            log( "Next note " + pitchName(note.pitch) + " " + ok );
                            // smallDump( chord, true );
                        }
                        break;
                    }
                }
                break;
            }
        }

        curScore.endCmd();
        write_file();
    }

    //============================================================================
    // Align the lyrics of all verses on this note based on a_mode:
    // "remove" remove horizontal offsets
    // "align"  align the left edges of lyrics
    // "number" insert verse numbers and align left edges
    function alignVerses( a_mode )
    {
        if (curScore.selection.elements.length == 0)
        {
            message("Error", "You must select a location at which to align verses");
            return;
        }

        time_stamp("Aligning verses: " + a_mode);

        curScore.startCmd();
        for (var ix=0; ix < curScore.selection.elements.length; ix++) {
            var chord = null;
            var element = curScore.selection.elements[ix];
            if (element.type == Element.CHORD) {
                chord = element;
            }
            else if (element.type == Element.NOTE) {
                chord = element.parent;
            }

            if (chord && (chord.type == Element.CHORD)) {
                var nVerses = chord.lyrics.length;
                log("Chord has " + nVerses + " verses\n");

                if (a_mode == "remove") {
                    // Clear out alignment offsets
                    for (vx = 0; vx < nVerses; vx++) {
                        var was = chord.lyrics[vx].offsetX;
                        chord.lyrics[vx].offsetX = 0;
                        log("Moved verse " + (vx+1) + " from " +
                             was.toFixed(2) + "\n");
                    }
                }
                else if (a_mode == "align") {
                    // Find the widest lyric
                    var widest = 0;
                    for (var vx = 0; vx < nVerses; vx++) {
                        var width = chord.lyrics[vx].bbox.width;
                        log("Verse " + (vx+1) + " lyric " + width.toFixed(2) + " wide\n");
                        if (width > widest) {
                            widest = width;
                        }
                    }
                    log("Widest lyric is " + widest + "\n");

                    if (widest/2 > Number(lyricLeftMax.text)) {
                        // Widest lyric would extend too far left. Limit it
                        widest = 2*Number(lyricLeftMax.text);
                    }

                    // Align to the widest lyric
                    for (vx = 0; vx < nVerses; vx++) {
                        var delta = (widest - chord.lyrics[vx].bbox.width)/2;
                        chord.lyrics[vx].offsetX = -delta;
                        log("Moved verse " + (vx+1) + " lyric by " +
                             delta.toFixed(2) + "\n");
                    }
                }
                else if (a_mode == "number") {
                    // Insert verse numbers
                    for (vx = 0; vx < nVerses; vx++) {
                        var text = chord.lyrics[vx].text;
                        if ((text[0] < '0') || (text[0] > '9')) {
                            chord.lyrics[vx].text = (chord.lyrics[vx].verse+1) + ". " + text;
                            log('Numbered verse as "' + chord.lyrics[vx].text + '"\n');
                        }
                        else {
                            log('Verse text already begins with number: "' +
                                chord.lyrics[vx].text + '"\n');
                        }
                    }
                }

                break;
            }
        }

        curScore.endCmd();
        write_file();
    }

    //============================================================================
    function message(a_title, a_message)
    {
        messageDialog.title = qsTranslate("PrefsDialogBase", a_title);
        messageDialog.text = qsTr(a_message);
        messageDialog.visible = false;
        messageDialog.open();
    }

    //============================================================================
    // DEBUG: Dump all defined properties of an object as a string
    function dumpObject( a_obj, a_values )
    {
        if (a_obj===null) {
            log("null\n");
            return;
        }
        else if (a_obj===undefined) {
            log("undefined\n");
            return;
        }

        up_nest("{");
        for (var prop in a_obj) {
            if (a_obj[prop]) {
                if (typeof a_obj[prop] === "function") {
                    log("function=" + prop + "\n");
                }
                else if (!a_values) {
                    log(prop + "\n");
                }
                else {
                    if (prop == "lyrics") {
                        // Recursive
                        up_nest("lyrics----------- with " + a_obj[prop].length + " elements");
                        for (var ix = 0; ix < a_obj[prop].length; ix++) {
                            dumpObject(a_obj[prop][ix], a_values);
                        }
                        down_nest();
                    }
                    else {
                        //showGoodStuff( prop, a_obj[prop], "\n" );
                        log(prop + "=" + a_obj[prop] + "\n");
                    }
                }
            }
        }

        down_nest();
        log("}\n");
    }

    //============================================================================
    // DEBUG: Dump selected properties of an object, one line each
    function smallDump( a_obj, a_recursive )
    {
        if (a_obj) {
            showGoodStuff("name",  a_obj.name, "  ");
            showGoodStuff("Type",  a_obj.type, "  ");
            showGoodStuff("eid",   a_obj.eid,  "  ");
            showGoodStuff("text",  a_obj.text, "\n");

            up_nest();
            showGoodStuff("tick",           a_obj.tick,  "\n");
            showGoodStuff("pitch",          a_obj.pitch, "\n");
            showGoodStuff("beat",           a_obj.beat,  "\n");
            showGoodStuff("duration",       a_obj.duration,  "\n");
            //showGoodStuff("visible",        a_obj.visible, "\n");
            showGoodStuff("actualDuration", a_obj.actualDuration,"\n");
            showGoodStuff("keySignature",   a_obj.keySignature,  "\n");
            showGoodStuff("timesigNominal", a_obj.timesigNominal,"\n");
            showGoodStuff("timesigActual",  a_obj.timesigActual, "\n");
            showGoodStuff("voice",          a_obj.voice, "\n");
            showGoodStuff("track",          a_obj.track, "\n");

            // Pointers
            showGoodStuff("parent",   a_obj.parent,   "\n");
            showGoodStuff("measure",  a_obj.measure,  "\n");
            showGoodStuff("next",     a_obj.next,     "\n");
            showGoodStuff("previous", a_obj.previous, "\n");

            // Arrays
            showGoodStuff("elements", a_obj.elements, "\n");
            showGoodStuff("segments", a_obj.segments, "\n");
            showGoodStuff("annotations", a_obj.annotations, "\n");
            showGoodStuff("notes",    a_obj.notes,  "\n");
            showGoodStuff("lyrics",   a_obj.lyrics, "\n");
            showGoodStuff("align",    a_obj.align,  "\n");
            down_nest();
        }
    }

    //============================================================================
    // DEBUG: Dump minimal properties of an object as a one-line string
    function tinyDump( a_obj )
    {
        if (a_obj) {
            showGoodStuff("name", a_obj.name, "  ");
            showGoodStuff("Type", a_obj.type, "  ");
            showGoodStuff("eid",  a_obj.eid,  "  ");
            showGoodStuff("text", a_obj.text, "");
        }
    }

    //============================================================================
    // If the value is defined and not null, log description and value
    // - Strings are wrapped in single quotes
    // - Objects are shown via tinyDump
    // - Note pitches are shown as C5
    function showGoodStuff( a_label, a_value, a_trailer )
    {
        if (a_value) {
            log(a_label + "=");

            if (typeof(a_value) == "string") {
                log('"' + a_value + '"');
            }
            else if (a_value.numerator !== undefined) {
                // Hack to see if this is a Fraction
                log("(" + a_value.numerator + "/" + a_value.denominator + ")");
            }
            else if (a_label == "pitch") {
                log(pitchName(a_value));
            }
            else if (a_label == "tick") {
                log( a_value + " (" + (a_value/480) + ")" );
            }
            else if (a_value.length != null) {
                up_nest("array of " + a_value.length);
                for (var ix = 0; ix < a_value.length; ix++) {
                    if (typeof a_value[ix] == "object") {
                        smallDump(a_value[ix]);
                    }
                    else {
                        showGoodStuff(ix.toString(), a_value[ix], "\n");
                    }
                }
                down_nest();
                return;     // Skip the trailer, since up_nest did a newline
            }
            else if (typeof a_value == "object") {
                 log("{");
                 tinyDump(a_value);
                 log("}");
            }
            else {
                log(a_value);
            }

            log(a_trailer);
        }
    }

    //============================================================================
    Item {
        anchors.fill: parent

        // Changes the color of all buttons (I'm too lazy to shape them)
        palette.button: "#D0D0D0"
        palette.buttonText: "#000000"

        GridLayout {
            columns: 6
            // columnSpacing: 1
            // rowSpacing: 1
            anchors.fill: parent
            anchors.margins: 10
            uniformCellWidths: false

            //-------------------------------------------------------------------
            // Lyric insertion
            TextArea {
                id: lyricText
                Layout.columnSpan: 3
                Layout.fillWidth: true
                wrapMode: TextEdit.Wrap
                placeholderText:
'Type or paste lyrics here, using multiple lines if desired, then insert them starting\n\
at the selected note. Hy-phen-at-ed words are inserted syllable by syllable.\n\
Words/syllables are centered under the note, but won\'t extend more than "max left."\n\
{text in brackets} is inserted on a single note, as when notating chant.'
                text: ""
            }

            ColumnLayout {
                spacing: 5
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    spacing: 5
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Label {
                        text: "Lyric max left"
                    }
                    TextField {
                        id: lyricLeftMax
                        // Layout.columnSpan: 1
                        Layout.preferredWidth: 30
                        text: "4"
                        validator: DoubleValidator {
                            bottom: 0.0
                            top: 50.0
                            decimals: 2
                            locale: "en"
                        }
                    }
                }

                RowLayout {
                    spacing: 5
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Label {
                        text: "Verse"
                    }
                    SpinBox {
                        id: verseNumber
                        Layout.preferredWidth: 70
                        value: 1
                        from: 1
                        to: 99
                        editable: true
                    }
                }
            }

            Button {
                id: insertLyricButton
                text: qsTranslate("PrefsDialogBase", "Insert word,\nsyllable,\nor {group}")
                onClicked: {
                    try_it(insertLyric, "insert")
                }
            }

            Button {
                id: nextNoteButton
                text: qsTranslate("PrefsDialogBase", "\nSkip note\n ")
                onClicked: {
                    try_it(insertLyric, "skip")
                }
            }

            //-------------------------------------------------------------------
            // Verse alignment
            GroupBox {
                title: "Align the lyrics of the selected note"
                Layout.columnSpan: 2
                Layout.fillWidth: true

                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    Layout.fillHeight: false

                    Button {
                        id: alignButton
                        //Layout.fillWidth: true
                        Layout.preferredWidth: 125
                        text: qsTranslate("PrefsDialogBase", "Align\nverses")
                        onClicked: {
                            try_it(alignVerses, "align")
                        }
                    }

                    Button {
                        id: numberAndAlignButton
                        //Layout.fillWidth: true
                        Layout.preferredWidth: 125
                        text: qsTranslate("PrefsDialogBase", "Number\nverses")
                        onClicked: {
                            try_it(alignVerses, "number")
                        }
                    }

                    Button {
                        id: removeAlignmentButton
                        //Layout.fillWidth: true
                        Layout.preferredWidth: 125
                        text: qsTranslate("PrefsDialogBase", "Remove\noffsets")
                        onClicked: {
                            try_it(alignVerses, "remove")
                        }
                    }
                }
            }

            //-------------------------------------------------------------------
            // Chant formatting
            GroupBox {
                title: "Format the selected measures (as for chant)"
                Layout.columnSpan: 4
                Layout.fillWidth: true

                RowLayout {
                    spacing: 3
                    Layout.fillWidth: true
                    Layout.fillHeight: false

                    StyledDropdown {
                        id: barlineType;
                        Layout.preferredWidth: 150
                        model: [
                            { 'text': "barlines: unchanged", 'type': "unchanged" },
                            { 'text': "barlines: Standard",  'type': "standard" },
                            { 'text': "barlines: Tick 1",    'type': "tick1"  },
                            { 'text': "barlines: Short 1",   'type': "short1" }
                        ]
                        currentIndex: 0
                        onActivated: function(index, value) {
                            currentIndex = index
                        }
                    }

                    StyledDropdown {
                        id: stemType;
                        Layout.preferredWidth: 140
                        model: [
                            { 'text': "stems: unchanged", 'type': "unchanged" },
                            { 'text': "stems: standard",  'type': "standard" },
                            { 'text': "stems: none",      'type': "none"  }
                        ]
                        currentIndex: 0
                        onActivated: function(index, value) {
                            currentIndex = index
                        }
                    }

                    Button {
                        id: chantifyButton
                        Layout.preferredWidth: 46
                        text: qsTranslate("PrefsDialogBase", "Format\n")
                        onClicked: {
                            try_it(chantify)
                        }
                    }
                }
            }
        }
    }

    MessageDialog {
        id: messageDialog
        title: ""
        text: ""
        onAccepted: {
            // quit()
        }
        // visible: false
    }

    FileIO {
        id: logFile
        source: tempPath() + "/" + title + "_log.txt"
    }
}
