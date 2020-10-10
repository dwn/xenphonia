import QtQuick 2.0
import QtQuick.Controls 1.3
import QtQuick.Controls.Styles 1.3
import MuseScore 3.0
MuseScore {
  version: '1.0'
  description: 'Retune selection, or whole score if nothing selected'
  menuPath: 'Plugins.Notes.Scl'
  pluginType: ''
  property variant scaleName;
  property variant pitchMap;
  property variant period;
  property variant lenScale;
  function tuneNote(note, parms) {
    const standardPitchMap = [
      -200,-100,0,100,200,
      1200,100,200,300,400,
      200,300,400,500,600,
      300,400,500,600,700,
      500,600,700,800,900,
      700,800,900,1000,1100,
      900,1000,1100,1200,1300];
    var tpc = note.tpc;
    var acc = note.accidental;
    var permut = [3,0,4,1,5,2,6];
    var tmp;
    tmp = tpc + 1;
    if (tmp <= 6) tmp = 5*permut[tmp%7];
    else if (tmp <= 13) tmp = 5*permut[(tmp-7)%7]+1;
    else if (tmp <= 20) tmp = 5*permut[(tmp-14)%7]+2;
    else if (tmp <= 27) tmp = 5*permut[(tmp-21)%7]+3;
    else if (tmp <= 34) tmp = 5*permut[(tmp-28)%7]+4;
    var centsOffset = (pitchMap[tmp] - standardPitchMap[tmp] + 2*period) % period;
    if (Math.abs(centsOffset - period) < Math.abs(centsOffset)) centsOffset-=period;
    if (Math.abs(centsOffset + period) < Math.abs(centsOffset)) centsOffset+=period;
    console.log(centsOffset+'<<');
    var periodIndex = Math.floor(note.pitch / 12);
    if (lenScale==19 && tmp==33) {
      periodIndex--;
    }
    else if (lenScale>19 && (tmp==33 || tmp==34)) {
      periodIndex--;
    }
    centsOffset += (periodIndex - 5) * period - (periodIndex - 5) * 1200;
    console.log(centsOffset + '   periodIndex ' + periodIndex + '    tmp ' + tmp);
    note.tuning = centsOffset;
  }

  function applyToNotesInSelection(func, parms) {
    var cursor = curScore.newCursor();
    cursor.rewind(1);
    var startStaff;
    var endStaff;
    var endTick;
    var fullScore = false;
    if (1) { //!cursor.segment) { // no selection //Uncomment to enable selection - personally I always want to retune the entire piece
      fullScore = true;
      startStaff = 0; // start with 1st staff
      endStaff = curScore.nstaves - 1; // and end with last
    } else {
      startStaff = cursor.staffIdx;
      cursor.rewind(2);
      if (cursor.tick == 0) {
        // this happens when the selection includes the last measure of the score
        // rewind(2) goes behind the last segment (where there's none) and sets tick=0
        endTick = curScore.lastSegment.tick + 1;
      } else {
        endTick = cursor.tick;
      }
      endStaff = cursor.staffIdx;
    }
    console.log(startStaff + " - " + endStaff + " - " + endTick)
    // Actual thing here //////////////////////////////////////////////////
    for (var staff = startStaff; staff <= endStaff; staff++) {
      for (var voice = 0; voice < 4; voice++) {
        cursor.rewind(1); // sets voice to 0
        cursor.voice = voice; //voice has to be set after goTo
        cursor.staffIdx = staff;
        if (fullScore)
          cursor.rewind(0) // if no selection, beginning of score
        var measureCount = 0;
        // After every track/voice, reset the currKeySig back to the original keySig
        parms.currKeySig = parms.keySig;
        console.log("currKeySig reset");
        // Loop elements of a voice
        while (cursor.segment && (fullScore || cursor.tick < endTick)) {
          // Reset accidentals if new measure.
          if (cursor.segment.tick == cursor.measure.firstSegment.tick) {
            parms.accidentals = {};
            measureCount ++;
            // console.log("Reset accidentals - " + measureCount);
          }
          /* Check for StaffText key signature changes.
          for (var i = 0, annotation = cursor.segment.annotations[i]; i < cursor.segment.annotations.length; i++) {
            var maybeKeySig = scanCustomKeySig(annotation.text);
            if (maybeKeySig !== null) {
              parms.currKeySig = maybeKeySig;
              console.log("detected new customer keySig: " + annotation.text);
            }
          }*/
          if (cursor.element) {
            if (cursor.element.type == Element.CHORD) {
              var graceChords = cursor.element.graceNotes;
              for (var i = 0; i < graceChords.length; i++) {
                // iterate through all grace chords
                var notes = graceChords[i].notes;
                for (var j = 0; j < notes.length; j++)
                  func(notes[j], parms);
              } 
              var notes = cursor.element.notes;
              for (var i = 0; i < notes.length; i++) {
                var note = notes[i];
                func(note, parms);
              }
            }
          }
          cursor.next();
        }
      }
    }
  }
  onRun: {
    console.log('Starting');
    if (typeof curScore === 'undefined')
      Qt.quit();
    var parms = {};
    parms.currKeySig = parms.keySig;
    parms.accidentals = {};
    var xhr = new XMLHttpRequest;
    xhr.open("GET", "input.scl");
    xhr.onreadystatechange = function() {
      if (xhr.readyState == XMLHttpRequest.DONE) {
        var scl = xhr.responseText;
        scl = scl.substring(scl.indexOf('!')+1);
        scaleName = scl.substring(0,scl.indexOf('!')).trim();
        scl = scl.substring(scl.indexOf('!')+1);
        scl = scl.substring(scl.indexOf('!'));
        scl = scl.substring(scl.indexOf('\n'));
        scl = scl.replace(/\!/g,'!$');
        scl = scl.split(/\!|\n/g);
        scl = scl.filter(function(el) { el = el.trim(); return (el!=='') && (el[0]!=='$'); });
        for(var i=0; i<scl.length; i++) scl[i]=scl[i].trim();
        console.log(scl);
        lenScale = scl.length;
        var scale = [];
        for(var i=0; i<lenScale; i++) {
          var p=scl[i].split('/');
          if (p.length==2) scl[i]=1200*Math.log(p[0]/p[1])*Math.LOG2E;
          else {
            p=scl[i].split('\\');
            if (p.length==2) scl[i]=(1200*p[0])/p[1];
          }
          scale.push(parseFloat(scl[i]));
        }
        console.log(scale);
        period = scale[lenScale-1];
        console.log('period ' + period);
        var pitch = [];
        if (lenScale==6) {
          //Interpolate to 12 notes
          var tmpScale = [];
          tmpScale.push(.5*scale[0]);
          tmpScale.push(scale[0]);
          tmpScale.push(.5*(scale[0]+scale[1]));
          tmpScale.push(scale[1]);
          tmpScale.push(.5*(scale[1]+scale[2]));
          tmpScale.push(scale[2]);
          tmpScale.push(.5*(scale[2]+scale[3]));
          tmpScale.push(scale[3]);
          tmpScale.push(.5*(scale[3]+scale[4]));
          tmpScale.push(scale[4]);
          tmpScale.push(.5*(scale[4]+scale[5]));
          tmpScale.push(scale[5]);
          scale=tmpScale;
          lenScale=scale.length;
          console.log('Interpolated from 6 to ' + lenScale + ' notes');
          console.log(scale);
        }
        else if (lenScale==7) {
          //Interpolate to 12 notes
          var tmpScale = [];
          tmpScale.push(.5*scale[0]);
          tmpScale.push(scale[0]);
          tmpScale.push(.5*(scale[0]+scale[1]));
          tmpScale.push(scale[1]);
          tmpScale.push(scale[2]);
          tmpScale.push(.5*(scale[2]+scale[3]));
          tmpScale.push(scale[3]);
          tmpScale.push(.5*(scale[3]+scale[4]));
          tmpScale.push(scale[4]);
          tmpScale.push(.5*(scale[4]+scale[5]));
          tmpScale.push(scale[5]);
          tmpScale.push(scale[6]);
          scale=tmpScale;
          lenScale=scale.length;
          console.log('Interpolated from 7 to ' + lenScale + ' notes');
          console.log(scale);
        }
        else if (lenScale==8) {
          //Interpolate to 12 notes
          var tmpScale = [];
          tmpScale.push(.5*scale[0]);
          tmpScale.push(scale[0]);
          tmpScale.push(scale[1]);
          tmpScale.push(.5*(scale[1]+scale[2]));
          tmpScale.push(scale[2]);
          tmpScale.push(scale[3]);
          tmpScale.push(.5*(scale[3]+scale[4]));
          tmpScale.push(scale[4]);
          tmpScale.push(scale[5]);
          tmpScale.push(.5*(scale[5]+scale[6]));
          tmpScale.push(scale[6]);
          tmpScale.push(scale[7]);
          scale=tmpScale;
          lenScale=scale.length;
          console.log('Interpolated from 8 to ' + lenScale + ' notes');
          console.log(scale);
        }
        //Set up map of pitches for all accidentals (double-flat, flat, none (natural), sharp, double-sharp)
        if (lenScale==12) {
          const diatonicSteps = [0,2,4,5,7,9,11];
          for(var i=0; i<7; i++) {
            var q = (diatonicSteps[i]+11) % 12;
            pitch.push(scale[(q+10) % 12]);
            pitch.push(scale[(q+11) % 12]);
            pitch.push(scale[q]);
            pitch.push(scale[(q+1) % 12]);
            pitch.push(scale[(q+2) % 12]);
          }
        }
        else if (lenScale==19) {
          const diatonicSteps = [0,3,6,8,11,14,17];
          for(var i=0; i<7; i++) {
            var q = (diatonicSteps[i]+18) % 19;
            pitch.push(scale[(q+17) % 19]);
            pitch.push(scale[(q+18) % 19]);
            pitch.push(scale[q]);
            pitch.push(scale[(q+1) % 19]);
            pitch.push(scale[(q+2) % 19]);
          }
        }
        else if (lenScale==21) {
          const diatonicSteps = [0,3,6,9,12,15,18];
          for(var i=0; i<7; i++) {
            var q = (diatonicSteps[i]+20) % 21;
            pitch.push(scale[(q+19) % 21]);
            pitch.push(scale[(q+20) % 21]);
            pitch.push(scale[q]);
            pitch.push(scale[(q+1) % 21]);
            pitch.push(scale[(q+2) % 21]);
          }
        }
        else if (lenScale==31) {
          const diatonicSteps = [0,5,10,13,18,23,28];
          for(var i=0; i<7; i++) {
            var q = (diatonicSteps[i]+30) % 31;
            pitch.push(scale[(q+29) % 31]);
            pitch.push(scale[(q+30) % 31]);
            pitch.push(scale[q]);
            pitch.push(scale[(q+1) % 31]);
            pitch.push(scale[(q+2) % 31]);
          }
        }
        else if (lenScale==35) {
          const diatonicSteps = [0,5,10,15,20,25,30];
          for(var i=0; i<7; i++) {
            var q = (diatonicSteps[i]+34) % 35;
            pitch.push(scale[(q+33) % 35]);
            pitch.push(scale[(q+34) % 35]);
            pitch.push(scale[q]);
            pitch.push(scale[(q+1) % 35]);
            pitch.push(scale[(q+2) % 35]);
          }
        }
        else {
          console.log('*** UNSUPPORTED SCALE LENGTH (ONLY 6, 7, 8, 12, 19, 21, 31, 35 NOTES) ***');
          Qt.quit();
        }
        pitchMap = pitch;
        applyToNotesInSelection(tuneNote, parms);
        console.log('*** THE TONIC OF YOUR PIECE OF MUSIC SHOULD BE "C" ***');
        console.log('Performed retuning to '+scaleName);
        Qt.quit();
      }
    };
    xhr.send();
  }
}
