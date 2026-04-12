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

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import MuseScore
import Muse.UiComponents

// For debug dump until console is fixed
import FileIO

MuseScore {
    version: "2.0.0"
    title: "Capo-stacker"
    description: "Insert capo chords ABOVE main chords"
    categoryCode: "composing-arranging-tools"
    pluginType: "dialog"
    thumbnailName: "capo-stacker.png"

    width:  360
    height: 240

    onRun: {
        if (!curScore) {
            message("Error", "No score open.\nThis plugin requires an open score to run.\n")
            quit()
        }
    }

    function applyCapo()
    {
        var trackNumber = getTrack();
        var capo = getCapo();
        curScore.startCmd()

        // Delete any existing capo or manually-inserted stacked chords
        deleteExtraChords(trackNumber);

        if (capo != 0) {
            var str = "Inserting capo chords on staff " + (trackNumber/4 + 1) + "\n";

            // Build a dictionary indexed by tick containing chords
            var allTheChords = ({});
            var showedCapoText = false;

            // Find chords on all voices of the specified track
            for (var voice = 0; voice < 4; voice++) {
                var cursor = curScore.newCursor();
                cursor.track = trackNumber + voice;
                cursor.rewind(Cursor.SCORE_START);

                while (cursor.segment) {
                    var annotations = cursor.segment.annotations;
                    for (var a in annotations) {
                        var annotation = annotations[a];
                        if ((annotation.name == "Harmony") && (annotation.text[0] != "(")) {
                            if (cursor.tick in allTheChords) {
                                if (allTheChords[cursor.tick] === annotation.text) {
                                    str += showWhere(cursor) + " Duplicate " + annotation.text + "\n";
                                }
                                else {
                                    str += "CONFLICTING CHORDS " +
                                           showWhere(cursor) + " Chord " + annotation.text +
                                           " vs previous " + allTheChords[cursor.tick] + "\n";
                                }
                            }
                            else {
                                // New chord
                                allTheChords[cursor.tick] = annotation.text;

                                // Add a capoed version of the chord to this voice
                                var tokens = parseChordSymbol(annotation.text);
                                var capoChord = annotation.clone();
                                capoChord.text = "(" + capoed(tokens[0], capo, "") +
                                                 tokens[1] +
                                                 capoed( tokens[2], capo, "/") + ")";
                                capoChord.play = false;

                                // If we use the default, the capo chords end up
                                // at different heights (-4.7 and a bit) depending
                                // on the main chord below them.
                                // Set an explicit value to smooth them out and
                                // line up the "Capo:X" text.
                                capoChord.offsetY = Number(offsetY.text);
                                cursor.add(capoChord);

                                str += showWhere(cursor) + " Chord " + annotation.text +
                                       " capoed to " + capoChord.text + "\n";

                                if (!showedCapoText) {
                                    // First chord symbol. Insert Capo text
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
                    }
                    cursor.next();
                }
            }

            logFile.write(str)
            resultText.placeholderText = "Capo actions may be found in\n" + logFile.source
        }
        curScore.endCmd()
    }

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

    // Delete all but the first chord at a given tick position and voice
    function deleteExtraChords(a_trackNumber)
    {
        for (var voice = 0; voice < 4; voice++) {
            var cursor = curScore.newCursor();
            cursor.track = a_trackNumber + voice;
            cursor.rewind(Cursor.SCORE_START);

            var tick = -1;
            while (cursor.segment) {
                var annotations = cursor.segment.annotations;
                // Careful looping, as we will be deleting elements
                for (let a=0; a < annotations.length; a++) {
                    var annotation = annotations[a];
                    if (annotation.name == "Harmony") {
                        if (cursor.tick != tick) {
                            // new chord position - leave it alone
                            tick = cursor.tick;
                        }
                        else {
                            // Extra chord, typically from a previous capo run
                            removeElement(annotation);
                            a--;    // back up the index to account for deletiong
                        }
                    }
                    else if ((annotation.name == "StaffText") &&
                              (annotation.text.indexOf("Capo:") == 0))
                    {
                         // Capo text, presumably from previous capo run
                         removeElement(annotation);
                         a--;    // back up the index to account for deletiong
                    }
                }
                cursor.next();
            }
        }
    }

    // Show info about of all chords
    function showChordInfo(a_trackNumber)
    {
        var str = "Showing chord data for staff " + (a_trackNumber/4 + 1) + "\n";

        for (var voice = 0; voice < 4; voice++) {
            var cursor = curScore.newCursor();
            cursor.track = a_trackNumber + voice;
            cursor.rewind(Cursor.SCORE_START);

            while (cursor.segment) {
                var annotations = cursor.segment.annotations;
                for (let a=0; a < annotations.length; a++) {
                    var annotation = annotations[a];
                    if ((annotation.name == "Harmony") ||
                        (annotation.name == "StaffText"))
                    {
                        // More than you want to know
                        // str += dumpObject(annotation, "");
                        str += showWhere(cursor) +
                               " " + annotation.name +
                               " " + annotation.text +
                               "\t pX=" + annotation.posX +
                               " pY="  + annotation.posY +
                               "\n";
                    }
                }
                cursor.next();
            }
        }
        logFile.write(str)
        resultText.placeholderText = "Chord information may be found in\n" + logFile.source
    }

    // Given a string representing a chord (e.g. "C#maj7b9/G#"), return
    // - Chord note including any sharp or flat
    // - stuff after the chord (min7...) if there is any (else "")
    // - If there is a slash, then Bass noteincluding any sharp or flat (else "")
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

    function message(a_title, a_message) {
        messageDialog.title = qsTranslate("PrefsDialogBase", a_title)
        messageDialog.text = qsTr(a_message)
        messageDialog.visible = false
        messageDialog.open()
    }

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
                id: chordTrack
                Layout.columnSpan: 2
                model: [
                    { 'text': "1", 'track': 0 },
                    { 'text': "2", 'track': 4 },
                    { 'text': "3", 'track': 8 },
                    { 'text': "4", 'track': 12 },
                    { 'text': "5", 'track': 16 },
                    { 'text': "6", 'track': 20 }
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
                    showChordInfo(getTrack());
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
                wrapMode: TextEdit.Wrap
                placeholderText: qsTr(".\n.")
            }
        }
    }

    function getTrack()
    {
        return chordTrack.model[chordTrack.currentIndex].track;
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

    // Show staff, voice, and tick position
    function showWhere( a_cursor )
    {
        return "Staff:" + (a_cursor.staffIdx+1) +
                " v" + (a_cursor.voice+1) +
                " tick:" + a_cursor.tick;
    }
}
