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

import MuseScore 3.0
import Muse.UiComponents

MuseScore {
    version: "1.0.0"
    title: "Capo-stacker"
    description: "Insert capo chords ABOVE main chords"
    categoryCode: "composing-arranging-tools"
    pluginType: "dialog"
    thumbnailName: "capo-stacker.png"

    width:  300
    height: 200

    onRun: {
        if (!curScore) {
            error("No score open.\nThis plugin requires an open score to run.\n")
            quit()
        }
    }

    function applyCapo()
    {
        var trackNumber = getTrack();
        var capo = getCapo();

        // Delete any existing capo or manually-inserted stacked chords
        deleteExtraChords(trackNumber);

        if (capo != 0) {
            // Search the current score for the chord symbols in the selected track.
            var cursor = curScore.newCursor();
            cursor.track = trackNumber;
            cursor.rewind(Cursor.SCORE_START);
            curScore.startCmd()

            var tick = -1;
            while (cursor.segment) {
                var annotations = cursor.segment.annotations;
                for (var a in annotations) {
                    var annotation = annotations[a];
                    if (annotation.name == "Harmony") {
                        if (cursor.tick != tick) {
                            // new base chord
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

                            if (tick < 0) {
                                // First chord symbol. Insert Capo text
                                // Ideally, want this just to the left of
                                // the first capo chord.
                                var capoText = newElement(Element.STAFF_TEXT);
                                capoText.text = "Capo: " + capo;
                                cursor.add(capoText);
                                capoText.offsetX = Number(offsetX.text);
                                capoText.offsetY = Number(offsetY.text);
                            }
                            tick = cursor.tick;
                        }
                    }
                }
                cursor.next();
            }
            curScore.endCmd()
        }
    }

    // Return the capoed equivalent of a note
    function capoed( a_note, a_capoPos, a_preChar )
    {
        // Map Chord note or /bass note to capoed equivalent.
        // Values set to match MuseScore 4.6.5 capo chords for chords without /bass.
        // Adding /bass causes Musescore to give different results in some cases
        // for the chord letter, the bass letter, or both.
        // Works fine for G7/F, deviates for things like Cb/G#
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

    // Delete all but the first chord at a given tick position
    function deleteExtraChords(a_trackNumber)
    {
        var cursor = curScore.newCursor();
        cursor.track = a_trackNumber;
        cursor.rewind(Cursor.SCORE_START);
        curScore.startCmd()

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
        curScore.endCmd();
    }

    // Show info about of all chords
    function showChordInfo(a_trackNumber)
    {
        curScore.startCmd()

        var str = "";
        var cursor = curScore.newCursor();
        cursor.track = a_trackNumber;
        cursor.rewind(Cursor.SCORE_START);

        while (cursor.segment) {
            var annotations = cursor.segment.annotations;
            for (let a=0; a < annotations.length; a++) {
                var annotation = annotations[a];
                if ((annotation.name == "Harmony") ||
                    (annotation.name == "StaffText"))
                {
                    str += cursor.tick + ": " +
                           annotation.name + " " +
                           annotation.text +
                           "\t pX=" + annotation.posX +
                           " pY=" + annotation.posY +
                           " oX=" + annotation.offsetX +
                           " oY=" + annotation.offsetY +
                           "\n";

                    // Goose it
                    annotation.pY += 0.1
                }
            }
            cursor.next();
        }
        curScore.endCmd()
        error(str);
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

    function error(errorMessage) {
        errorDialog.text = qsTr(errorMessage)
        errorDialog.visible = false
        errorDialog.open()
    }

    Item {
        anchors.fill: parent

        GridLayout {
            columns: 2
            anchors.fill: parent
            anchors.margins: 10

            Label {
                text: "Staff with chords"
            }
            StyledDropdown {
                id: chordTrack
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
                text: "Capo label X offset"
            }
            TextField {
                id: offsetX
                text: "-12"  // Trying for just left of the first chord
                validator: DoubleValidator {
                    bottom: -999.0
                    top: 999.0
                    decimals: 2
                    locale: "en"
                }
            }

            Label {
                text: "Capo label Y offset"
            }
            TextField {
                id: offsetY
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
                    // quit()
                }
            }

            Button {
                id: cancelButton
                text: qsTranslate("PrefsDialogBase", "Close")
                onClicked: {
                    quit()
                }
            }
            
            Button {
                id: infoButton
                text: qsTranslate("PrefsDialogBase", "Show Info")
                onClicked: {
                    showChordInfo(getTrack());
                }
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
        id: errorDialog
        title: "Error"
        text: ""
        onAccepted: {
            // quit()
        }
        // visible: false
    }
    
    // Hoped this woul resolve the "action=main" warning in the log, but nope.
    function main()
    {
    }
}
