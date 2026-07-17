// Dump MuseScore score Elements
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
    version: "1.0.6"
    title: "Dumper"
    description: "Dump selected score and Element info"
    // categoryCode: "composing-arranging-tools"
    pluginType: "dialog"
    thumbnailName: "dumper.png"

    width:  760
    height: 360

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
    // Dump the current selection as elements
    function dumpSelectionElements()
    {
        resultText.placeholderText = "\n.";
        if (curScore.selection.elements.length == 0)
        {
            message("Error", "You must select something to dump.");
            return;
        }

        time_stamp("Dumping Selection by Elements");
        var selectedElements = curScore.selection.elements;
        for (var i=0; i<selectedElements.length; i++) {
            if (showAll.checked) {
                dumpObject( selectedElements[i], true );
            }
            else {
                smallDump( selectedElements[i], true );
            }
        }

        write_file();
        resultText.placeholderText = "Details may be found in\n" + logFile.source;
    }

    //============================================================================
    // Dump the current selection via a cursor
    function dumpSelectionCursor()
    {
        resultText.placeholderText = "\n.";
        if (curScore.selection.elements.length == 0)
        {
            message("Error", "You must select something to dump.");
            return;
        }

        time_stamp("Dumping Selection by Cursor");

        var cursor = curScore.newCursor();
        cursor.rewind( Cursor.SELECTION_END );
        var endTick = cursor.tick;
        cursor.rewind( Cursor.SELECTION_START );
        while (cursor.tick < endTick) {
            up_nest("Cursor at " + cursor.tick);
            if (showAll.checked)
                dumpObject( cursor, true );
            else
                smallDump( cursor, false );

            up_nest("Element");
            if (showAll.checked)
                dumpObject( cursor.element, true );
            else
                smallDump( cursor.element, false );
            down_nest();

            up_nest("Segment");
            if (showAll.checked)
                dumpObject( cursor.segment, true );
            else
                smallDump( cursor.segment, false );
            down_nest();

            up_nest("Measure");
            if (showAll.checked)
                dumpObject( cursor.measure, true );
            else
                smallDump( cursor.measure, false );
            down_nest();
            down_nest();

            cursor.next();
        }

        write_file();
        resultText.placeholderText = "Details may be found in\n" + logFile.source;
    }

    //============================================================================
    // Dump the current selection as segments
    function dumpSelectionSegments()
    {
        resultText.placeholderText = "\n.";
        time_stamp("Dumping Selection by Segments");

        var segment = curScore.selection.startSegment;
        while (segment && (segment.tick < curScore.selection.endSegment.tick)) {
            smallDump(segment, false);
            up_nest();
            // Loop on TRACK
            for (var ix = 0; ix < curScore.ntracks; ix++) {
                var el = segment.elementAt(ix);
                if (el) {
                    up_nest("Element on track " + ix + " of Segment");
                    if (showAll.checked)
                        dumpObject(el, true);
                    else
                        smallDump(el, false);
                    down_nest();
                }
            }

            down_nest();
            log("\n");
            segment = segment.next;
        }

        write_file();
        resultText.placeholderText = "Details may be found in\n" + logFile.source;
    }

    //============================================================================
    // DEBUG: Enumerate the properties of an object
    property var m_classes:  ({})    // build a dictionary of classes
    property var m_pointers: ["parent", "measure", "next", "previous"];
    property var m_arrays:   ["elements", "segments", "annotations", "notes",
                              "lyrics", "articulations", "graceNotes", //"align",
                              "dots", "brackets"];
    function enumerateObject( a_obj )
    {
        if (a_obj) {
            if (!m_classes[a_obj.name]) {
                var str = "Class " + a_obj.name + "\n";
                log("  Found " + str);
                if (a_obj.name == null) {
                    log("  Undefined! " + (typeof a_obj) + "\n");
                }

                // Generate an alphabetical list of property names
                var propNames = [];
                for (var propx in a_obj) {
                    propNames.push(propx);
                }
                propNames.sort();

                for (var ix = 0; ix < propNames.length; ix++) {
                    var prop = propNames[ix];
                    if (a_obj[prop]) {
                        var type = typeof a_obj[prop];
                        if (type != "object") {
                            // Primitive type
                            str += "   " + prop + "  (" + type + ")\n";
                        }
                        else if (a_obj[prop].numerator !== undefined) {
                            // Hack to see if this is a Fraction
                            str += "   " + prop + "  (franction)\n";
                        }
                        else if (a_obj[prop].length != null) {
                            str += "   " + prop + "  (array)\n";
                        }
                        else {
                            str += "   " + prop + "\n";
                        }
                    }
                }
                m_classes[a_obj.name] = str;
            }
            else {
                // TODO: we COULD check for previously unseen properties
                // log( "duplicate class " + a_obj.name + "\n");
            }

            // Since pointer and array properties will differ from instance
            // to instance, process them even for previously-seen classes.
            //
            // Doing this for pointers (especially parent, next, and previous)
            // would likely cause infinite recursion
            for (var prop in m_arrays) {
                var propName = m_arrays[prop];
                if (a_obj[propName]) {
                    // log("  Recursing on array property" + propName + "\n");
                    for (var ix = 0; ix < a_obj[propName].length; ix++) {
                        if (typeof a_obj[propName][ix] == "object") {
                            enumerateObject(a_obj[propName][ix]);
                        }
                    }
                }
            }
        }
    }

    //============================================================================
    // Build and dump a listing of object classes and their properties
    function dumpClasses()
    {
        resultText.placeholderText = "\n.";
        m_classes = {};

        time_stamp("Dumping Classes");

        // Recursively dump measures
        log("Dumping Measures\n");
        var measure = curScore.firstMeasure;
        while (measure) {
            enumerateObject(measure);
            measure = measure.nextMeasure;
        }

        // Recursively dump segments
        log("\nDumping Segments\n");
        var segment = curScore.firstSegment();
        while (segment) {
            enumerateObject(segment);
            // Recursively dump elements of this segment
            for (var ix = 0; ix < curScore.ntracks; ix++) {
                var el = segment.elementAt(ix);
                if (el) {
                    enumerateObject(el);
                }
            }

            segment = segment.next;
        }

        // Recursively dump staves
        log("\nDumping Staves\n");
        for (var ix = 0; ix < curScore.staves.length; ix++) {
            enumerateObject(curScore.staves[ix]);
        }

        // Dump the accumulated classes in alphabetical order
        log("\nAccumulated classes");
        var sortedKeys = Object.keys(m_classes).sort()
        for (var ix = 0; ix < sortedKeys.length; ix++) {
            log("\n" + m_classes[sortedKeys[ix]]);
        }

        write_file();
        resultText.placeholderText = "Details may be found in\n" + logFile.source;
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
            // showGoodStuff("align",    a_obj.align,  "\n");
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
            CheckBox {
                    id: showAll
                    text: qsTr("Show all\nproperties")
                    checked: false
                    onClicked: {
                        checked = !checked;
                    }
                }

            Button {
                id: dumpSelectionButton
                text: qsTranslate("PrefsDialogBase", "Show Selection\nElements")
                onClicked: {
                    try_it(dumpSelectionElements)
                }
            }

            Button {
                id: dumpCursorButton
                text: qsTranslate("PrefsDialogBase", "Show Selection\nby Cursor")
                onClicked: {
                    try_it(dumpSelectionCursor)
                }
            }

            Button {
                id: dumpSegmentsButton
                text: qsTranslate("PrefsDialogBase", "Show selection\nby segment")
                onClicked: {
                    try_it(dumpSelectionSegments)
                }
            }

            Button {
                id: dumpClassesButton
                text: qsTranslate("PrefsDialogBase", "Show classes\n")
                onClicked: {
                    try_it(dumpClasses)
                }
            }

            //-------------------------------------------------------------------
            TextArea {
                id: resultText
                Layout.columnSpan: 5
                Layout.fillWidth: true
                wrapMode: TextEdit.Wrap
                placeholderText: "Actions will be applied to the current selection, \
if any, else to the entire score.\nResults will be shown here."
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
