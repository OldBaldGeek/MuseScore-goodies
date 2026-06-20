// Insert capo chord symbols ABOVE regular chord symbols
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

// ISSUES AND LIMITATIONS:
// If the beat or sub-beat where a chord symbol appears has no note or rest,
// the Cursor won't stop there, and a script cannot add a symbol for the capo-chord.
//
// This plug-in uses a hack to sneak around the problem by using Voice 4:
// - The plug-in checks Voice 4 of the staff being processed for any notes or rests.
//   If any are found, a warning is generated and processing stops.
// - Traverse the selected region:
//   - If a chord symbol is found on a beat that DOES NOT have a note or rest,
//     insert a rest on that beat in Voice 4.
//   - Add the capoed chord symbol (which will be associated either with a "real"
//     note or rest, or with the rest just added to Voice 4.)
// - After processing the entire selection, delete anything in Voice 4.
//
// It seems to me that few scores with chord symbols will also use Voice 4 on the
// staff with the chord symbols.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import MuseScore
import Muse.UiComponents

// For debug dump until console is fixed
import FileIO

MuseScore {
    version: "3.0.1"
    title: "Capo-stacker"
    description: "Insert capo chords ABOVE main chords"
    categoryCode: "composing-arranging-tools"
    pluginType: "dialog"
    thumbnailName: "capo-stacker.png"

    width:  380
    height: 280

    // Offset to the voice used for added rests (usually V4)
    property int hackVoice: 3

    onRun: {
        if (!curScore) {
            message("Error", "No score open.\nThis plugin requires an open score to run.\n")
            quit()
        }
    }

    //============================================================================
    // Remove any existing capo chords, and add new ones as specified
    function applyCapo()
    {
        resultText.placeholderText = "\n.";

        var staffNumber = getStaff(); // staff 0 to N-1
        selectIfNeeded(staffNumber);

        var str = checkHackVoice(staffNumber);
        if (str != "") {
            var errmsg = "Elements were found in Voice " + (hackVoice+1) +
                          " which we may need to use.";
            logFile.write(errmsg + "\n" + str);
            resultText.placeholderText = "Details may be found in\n" + logFile.source;

            message("Error", errmsg + ". See log file.\n");
            return;
        }

        str = title + " " + version + "\n";

        // Delete any existing capo chord symbols
        curScore.startCmd();
        str += deleteCapoChords(staffNumber);
        curScore.endCmd();

        var capo = getCapo();
        if (capo != 0) {
            curScore.startCmd();

            str += "\nInserting capo chords on staff " + (staffNumber + 1) + "\n";
            var sel = getSelectedElements(staffNumber);
            str += "Selection has " + sel.length + " elements for staff " +
                   (staffNumber + 1) + "\n";

            var showedCapoText = false;
            var cursor = curScore.newCursor();
            for (var i=0; i<sel.length; i++) {
                if (sel[i] && (sel[i].type == Element.HARMONY)) {
                    var tokens = parseChordSymbol(sel[i].text);
                    str += "Harmony element at " + sel[i].parent.tick +
                           " is " + sel[i].text +
                           " [" + tokens[0] + ", " + tokens[1] +
                           ", " + tokens[2] + "]\n";

                    var capoChord = sel[i].clone();
                    capoChord.text = "(" + capoed(tokens[0], capo, "") +
                                     tokens[1] +
                                     capoed( tokens[2], capo, "/") + ")";
                    capoChord.fontSize += Number(sizeAdjust.text);
                    capoChord.play = false;

                    // If we use the defaults, the capo chords may end up
                    // at different heights (-4.7 and a bit) depending
                    // on the main chord below them.
                    // Set an explicit value to smooth them out and to
                    // align with the "Capo:X" text.
                    capoChord.offsetY = Number(offsetY.text);

                    var chordTick = sel[i].parent.tick;
                    cursor.rewindToTick(chordTick);
                    if (cursor.tick != chordTick) {
                        // Chord symbol is at a tick location where there is no
                        // note or rest, so cursor can't rewind to there.
                        // Add a temporary rest to hang the chord symbol on.
                        str += "  Floating chord symbol at " + chordTick +
                               " vs cursor at " + cursor.tick + "\n";
                        cursor.prev();
                        cursor.track += hackVoice;
                        var deltaTicks = chordTick - cursor.tick;
                        str += "  Back up cursor to tick " + cursor.tick +
                               " on track " + (hackVoice+1) +
                               " and add " + deltaTicks + " ticks of rest\n";
                        cursor.setDuration( deltaTicks/60, 32 );
                        cursor.addRest();

                        // Add a sixteenth rest on which to hang the chord symbol
                        // then back up the cursor so we can aded the chord there
                        cursor.setDuration( 2, 32 );
                        cursor.addRest();
                        cursor.prev();
                        cursor.track -= hackVoice;
                    }

                    cursor.add(capoChord);
                    str += "  Added capo chord " + smallDump(capoChord);

                    if (!showedCapoText) {
                        // First chord symbol. Insert "Capo:N" text
                        // Ideally, want this just to the left of
                        // the first capo chord.
                        var capoText = newElement(Element.STAFF_TEXT);
                        capoText.text = "Capo: " + capo;
                        cursor.add(capoText);
                        capoText.offsetX = Number(offsetX.text);
                        capoText.offsetY = Number(offsetY.text);
                        showedCapoText = true;
                    }
                }
            }

            // Remove any rests we added
            str += deleteAddedRests(staffNumber);
            curScore.endCmd();
        }

        logFile.write(str);
        resultText.placeholderText = "Details of actions may be found in\n" + logFile.source;
    }

    //============================================================================
    // Select the specified staff if there is currently no range selected.
    function selectIfNeeded(a_staffNumber)
    {
        if ((curScore.selection.elements.length == 0) || !curScore.selection.isRange)
        {
            curScore.startCmd();
            curScore.selection.selectRange(0, curScore.lastSegment.tick + 1,
                                           a_staffNumber, a_staffNumber + 1);
            curScore.endCmd();
        }
    }

    //============================================================================
    // Return an array of the Elements for this staff in the selected range
    function getSelectedElements(a_staffNumber)
    {
        var selectedElements = curScore.selection.elements;
        var sel = [];
        for (var i=0; i<selectedElements.length; i++) {
            if (selectedElements[i].track/4 == a_staffNumber) {
                sel.push(selectedElements[i]);
            }
        }
        return sel;
    }

    //============================================================================
    // Check Hack Voice for existing items we might damage if we added rests.
    // Return empty string if nothing found, else description of the items.
    //
    // This checks the ENTIRE score, not just the selection.
    // We could rewind to SCORE_SELECTION, but would need to terminate at the END
    // of the selection. And use of the voice ANYWHERE seems fraught.
    function checkHackVoice(a_staffNumber)
    {
        var str = "";
        var cursor = curScore.newCursor();
        cursor.track = 4*a_staffNumber + hackVoice;
        cursor.rewind(Cursor.SCORE_START);

        while (cursor.element) {
            str += "Voice " + (hackVoice + 1) + " has " + smallDump(cursor.element);
            cursor.next();
        }
        return str;
    }

    //============================================================================
    // Remove any rests we added to hang chords on.
    //
    // This cleans the ENTIRE score, not just the selection.
    // We could rewind to SCORE_SELECTION, but would need to terminate at the END
    // of the selection. And use of the voice ANYWHERE seems fraught.
    function deleteAddedRests(a_staffNumber)
    {
        var str = "Removing temporary rests from staff " + (a_staffNumber + 1) +
                  " Voice " + (hackVoice + 1) + "\n";
        var cursor = curScore.newCursor();
        cursor.track = 4*a_staffNumber + hackVoice;
        cursor.rewind(Cursor.SCORE_START);

        while (cursor.element) {
            if (cursor.element.type == Element.REST) {
                str += "  Deleting " + smallDump(cursor.element);
                removeElement(cursor.element);
            }
            cursor.next();
        }
        return str;
    }

    //============================================================================
    // Delete any non-playing chords in parenthesis, and the text "Capo:X"
    function deleteCapoChords(a_staffNumber)
    {
        var str = "Removing capo chords from staff " + (a_staffNumber + 1) + "\n";
        var sel = getSelectedElements(a_staffNumber);
        str += "  Selection has " + sel.length + " elements for staff " +
               (a_staffNumber + 1) + "\n";

        for (var i=0; i<sel.length; i++) {
            var element = sel[i];
            if (element) {
                if ((element.type == Element.HARMONY) &&
                    (element.text[0] == "(") &&
                    (!element.play))
                {
                    // Non-playing chord symbol in parentheses assumed to be capo
                    str += "  Deleting chord symbol - " + smallDump(element);
                    removeElement(element);
                }
                else if ((element.type == Element.STAFF_TEXT) &&
                          (element.text.indexOf("Capo:") == 0))
                {
                     // Capo text, assumed to be from previous capo run
                    str += "  Deleting Capo text - " + smallDump(element);
                    removeElement(element);
                }
            }
        }

        // Delete any temporary rests in our hack voice
        str += deleteAddedRests(a_staffNumber);
        return str;
    }

    //============================================================================
    // Show info about of all chords
    function showChordInfo(a_staffNumber)
    {
        selectIfNeeded(a_staffNumber);

        resultText.placeholderText = "\n.";
        var str = title + " " + version + " Showing chord data for staff " +
                  (a_staffNumber + 1) + "\n";

        var str2 = checkHackVoice(a_staffNumber);
        if (str2 != "") {
            var errmsg = "Unexpected items in Voice " + (hackVoice+1);
            str += errmsg + "\n" + str2;
            message("Warning", errmsg);
        }

        str += "Chord symbols\n";
        var sel = getSelectedElements(a_staffNumber);
        str += "Selection has " + sel.length + " elements for staff " +
               (a_staffNumber + 1) + "\n";

        for (var i=0; i<sel.length; i++) {
            var element = sel[i];
            if (element) {
                if (element.type == Element.HARMONY) {
                    str += "  " + smallDump(element);
                }
                else if (element.type == Element.STAFF_TEXT) {
                    str += "  " + smallDump(element);
                }
            }
        }

        logFile.write(str);
        resultText.placeholderText = "Chord information may be found in\n" + logFile.source;
    }

    //============================================================================
    // Return the capoed equivalent of a note
    function capoed( a_note, a_capoPos, a_preChar )
    {
        // Map Chord note or /bass note to capoed equivalent.
        // Values set to match MuseScore 4.6.5 capo chords for chords without /bass.
        // Adding /bass causes Musescore to give different results in some cases
        // for the chord letter, the bass letter, or both.
        // Works fine for G7/F, deviates for exotica like Cb/G#
        var capoMapper = {
         //  note     1     2     3     4     5     6     7     8     9    10    11
            "Cb" : [ "Bb", "A",  "Ab", "G",  "Gb", "F",  "E",  "Eb", "D",  "Db", "C"  ],
            "C"  : [ "B",  "Bb", "A",  "Ab", "G",  "F#", "F",  "E",  "Eb", "D",  "Db" ],
            "C#" : [ "C",  "B",  "A#", "A",  "G#", "G",  "F#", "F",  "E",  "D#", "D"  ],
                                                         
            "Db" : [ "C",  "B",  "Bb", "A",  "Ab", "G",  "Gb", "F",  "E",  "Eb", "D"  ],
            "D"  : [ "C#", "C",  "B",  "Bb", "A",  "G#", "G",  "F#", "F",  "E",  "Eb" ],
            "D#" : [ "D",  "C#", "C",  "B",  "A#", "A",  "G#", "G",  "F#", "F",  "E"  ],
                                                         
            "Eb" : [ "D",  "Db", "C",  "B",  "Bb", "A",  "Ab", "G",  "Gb", "F",  "E"  ],
            "E"  : [ "D#", "D",  "C#", "C",  "B",  "A#", "A",  "G#", "G",  "F#", "F"  ],
            "E#" : [ "E",  "D#", "D",  "C#", "C",  "B",  "A#", "A",  "G#", "G",  "F#" ],

            "Fb" : [ "Eb", "D",  "Db", "C",  "B",  "Bb", "A",  "Ab", "G",  "Gb", "F"  ],
            "F"  : [ "E",  "Eb", "D",  "Db", "C",  "B",  "Bb", "A",  "Ab", "G",  "Gb" ],
            "F#" : [ "F",  "E",  "D#", "D",  "C#", "C",  "B",  "A#", "A",  "G#", "G"  ],

            "Gb" : [ "F",  "E",  "Eb", "D",  "Db", "C",  "B",  "Bb", "A",  "Ab", "G"  ],
            "G"  : [ "F#", "F",  "E",  "Db", "D",  "C#", "C",  "B",  "Bb", "A",  "Ab" ],
            "G#" : [ "G",  "F#", "F",  "E",  "D#", "D",  "C#", "C",  "B",  "A#", "A"  ],

            "Ab" : [ "G",  "Gb", "F",  "E",  "Eb", "D",  "Db", "C",  "B",  "Bb", "A"  ],
            "A"  : [ "G#", "G",  "F#", "F",  "E",  "D#", "D",  "C#", "C",  "B",  "Bb" ],
            "A#" : [ "A",  "G#", "G",  "F#", "F",  "E",  "D#", "D",  "C#", "C",  "B"  ],

            "Bb" : [ "A",  "Ab", "G",  "Gb", "F",  "E",  "Eb", "D",  "Db", "C",  "B"  ],
            "B"  : [ "Bb", "A",  "G#", "G",  "F#", "F",  "E",  "D#", "D",  "C#", "C"  ],
            "B#" : [ "B",  "A#", "A",  "G#", "G",  "F#", "F",  "E",  "D#", "D",  "C#" ]
        }

        if (a_note in capoMapper) {
            return a_preChar + capoMapper[a_note][a_capoPos-1];
        }
        return "";
    }

    //============================================================================
    // Given a string representing a chord (e.g. "C#maj7b9/G#"), return
    // - Chord note including any sharp or flat
    // - stuff after the chord (min7...) if there is any (else "")
    // - If there is a slash, then Bass note including any sharp or flat (else "")
    // 
    function parseChordSymbol(symbol) {
        // Use a regex to split the chord symbol into an array of tokens.
        var tokens = symbol.match(
           /^([A-Ga-g])?([#♯])?([b♭])?([^\/]*)(\/([A-Ga-g])([#♯])?([b♭])?)?/
        );
        // [0] has entire string
        // [1] has chord letter
        // [2] has sharp or undefined
        // [3] has flat or undefined
        // [4] has annotation (m, sus etc)
        // [5] has /bass or undefined
        // [6] has bass note letter
        // [7] has sharp or undefined
        // [8] has flat or undefined
        var chordNote = tokens[1] ? tokens[1] : "";
        if (!(tokens[2] === undefined)) chordNote += '#';
        if (!(tokens[3] === undefined)) chordNote += 'b';
        var bassNote = tokens[6] ? tokens[6] : "";
        if (!(tokens[7] === undefined)) bassNote += '#';
        if (!(tokens[8] === undefined)) bassNote += 'b';

        return [ chordNote, tokens[4] ? tokens[4] : "", bassNote ];
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
    // DEBUG: Dump defined properties of an object as a string
    function dumpObject( a_obj, a_indent )
    {
        var str = a_indent + "{{{\n";
        for (var prop in a_obj) {
            if (!(a_obj[prop] === undefined)) {
                if (typeof a_obj[prop] === "function") {
                    str += a_indent + "FUNCTION: " + prop + "\n";
                }
                else {
                    str += a_indent + prop + " (" + (typeof a_obj[prop]) + "): " + a_obj[prop] + "\n";
                    if ((typeof a_obj[prop] === "object") && (a_indent === "")) {
                        str += dumpObject( a_obj[prop], "   " ) + "\n";
                    }
                }
            }
        }
        return str + a_indent + "}}}\n";
    }

    //============================================================================
    // DEBUG: Dump selected properties of an object as a string
    function smallDump( a_obj )
    {
        var str = "";
        if (a_obj) {
            str += showGoodStuff("Type:",   a_obj.type) +
                   showGoodStuff("name:",  a_obj.name) +
                   showGoodStuff("subType:", a_obj.subtypeName()) +
                   showGoodStuff("text:",  a_obj.text);
            if (a_obj.tick) {
                str += showGoodStuff("tick:", a_obj.tick);
            }
            else {
                str += showGoodStuff("tick:", a_obj.parent.tick);
            }
            //str += showGoodStuff("pX:", a_obj.posX);
            str += showGoodStuff("pY:", a_obj.posY);

            if (a_obj.actualDuration) {
                str += showGoodStuff("duration:", a_obj.actualDuration.str);
            }

            // Scan parents to fine the containing measure
            var ob = a_obj;
            var measure = a_obj.measure;
            while (!measure) {
                // see if a parent is a Measure
                ob = ob.parent;
                if (!ob) {
                    break;  // no Measure parent
                }
                if (ob.type === Element.MEASURE) {
                    measure = ob;
                }
            }
            if (measure) {
                var measureNumber = 1;
                var meas = curScore.firstMeasure;
                while (meas) {
                    if (meas.is(measure)) {
                        break;
                    }
                    meas = meas.nextMeasure;
                    measureNumber += 1;
                }
                str += showGoodStuff("Measure:", measureNumber);
            }
        }

        return str + "\n";
    }

    //============================================================================
    // If the value is defined and not null, return description and value, else ""
    // Strings are wrapped in single quotes
    function showGoodStuff( a_label, a_value )
    {
        if (a_value == null) {
            return "";
        }

        if (typeof(a_value) == "string") {
            a_value = "'" + a_value + "'";
        }

        return a_label + a_value + "\t";
    }

    //============================================================================
    // Show staff, voice, and tick position
    function showWhere( a_cursor )
    {
        return "Staff:" + (a_cursor.staffIdx+1) +
                " v" + (a_cursor.voice+1) +
                " tick:" + a_cursor.tick;
    }

    //============================================================================
    Item {
        anchors.fill: parent

        GridLayout {
            columns: 3
            anchors.fill: parent
            anchors.margins: 20
            uniformCellWidths: true

            Label {
                text: "Staff with chords"
            }
            StyledDropdown {
                id: chordStaff
                Layout.columnSpan: 2
                model: [
                    { 'text': "1", 'staff': 0 },
                    { 'text': "2", 'staff': 1 },
                    { 'text': "3", 'staff': 2 },
                    { 'text': "4", 'staff': 3 },
                    { 'text': "5", 'staff': 4 },
                    { 'text': "6", 'staff': 5 }
                ]
                currentIndex: 0
                onActivated: function(index, value) {
                    currentIndex = index
                }
            }

            Label {
                text: "Capo fret"
            }
            StyledDropdown {
                id: chordCapo
                Layout.columnSpan: 2
                model: [
                    { 'text': "none (remove)", 'capo': 0 },
                    { 'text': "1", 'capo': 1 },
                    { 'text': "2", 'capo': 2 },
                    { 'text': "3", 'capo': 3 },
                    { 'text': "4", 'capo': 4 },
                    { 'text': "5", 'capo': 5 },
                    { 'text': "6", 'capo': 6 },
                    { 'text': "7", 'capo': 7 },
                    { 'text': "8", 'capo': 8 },
                    { 'text': "9", 'capo': 9 },
                    { 'text': "10",'capo': 10 },
                    { 'text': "11",'capo': 11 }
                ]
                currentIndex: 0
                onActivated: function(index, value) {
                    currentIndex = index
                }
            }
            
            Label {
                text: "Capo text X offset"
            }
            TextField {
                id: offsetX
                Layout.columnSpan: 2
                text: "-12"  // Trying for just left of the first chord
                validator: DoubleValidator {
                    bottom: -999.0
                    top: 999.0
                    decimals: 2
                    locale: "en"
                }
            }

            Label {
                text: "Capo text Y offset"
            }
            TextField {
                id: offsetY
                Layout.columnSpan: 2
                text: "-5"  // Trying for same level as the first chord
                validator: DoubleValidator {
                    bottom: -999.0
                    top: 999.0
                    decimals: 2
                    locale: "en"
                }
            }

            Label {
                text: "Capo text size adjust"
            }
            TextField {
                id: sizeAdjust
                Layout.columnSpan: 2
                text: "0"  // Same size as non-capo chords
                validator: IntValidator {
                    bottom: -3
                    top: 3
                    locale: "en"
                }
            }

            Button {
                id: applyButton
                text: qsTranslate("PrefsDialogBase", "Apply")
                onClicked: {
                    applyCapo()
                }
            }

            Button {
                id: infoButton
                text: qsTranslate("PrefsDialogBase", "Show Info")
                onClicked: {
                    showChordInfo(getStaff());
                }
            }

            Button {
                id: cancelButton
                text: qsTranslate("PrefsDialogBase", "Close")
                onClicked: {
                    quit()
                }
            }

            TextArea {
                id: resultText
                Layout.columnSpan: 3
                Layout.fillWidth: true
                wrapMode: TextEdit.Wrap
                placeholderText: "Actions will be applied to the current selection, " +
                                 "if any,\nelse to the entire score.\n"
            }
        }
    }

    function getStaff()
    {
        return chordStaff.model[chordStaff.currentIndex].staff;
    }

    function getCapo()
    {
        return chordCapo.model[chordCapo.currentIndex].capo;
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
    
    // Hoped this would resolve the "action=main" warning in the log, but nope.
    function main()
    {
    }

    FileIO {
        id: logFile
        source: tempPath() + "/capo-stacker-log.txt"
    }
}
