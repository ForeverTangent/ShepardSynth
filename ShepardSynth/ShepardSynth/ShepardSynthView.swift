//
//  ShepardSynthView.swift
//  ShepardSynth
//
//  Created by Stanley Rosenbaum on 10/30/20.
//

import AudioKit
import CoreMIDI
import Foundation
import SwiftUI
import Sliders

// struct represeting last data received of each type

// MARK: - MIDI

struct MIDIMonitorData {
	var noteOn = 0
	var velocity = 0
	var noteOff = 0
	var channel = 0
	var afterTouch = 0
	var afterTouchNoteNumber = 0
	var programChange = 0
	var pitchWheelValue = 0
	var controllerNumber = 0
	var controllerValue = 0

}

class MIDIMonitorConductor: ObservableObject, MIDIListener {

	let midi = MIDI()
	@Published var data = MIDIMonitorData()

	init() {}

	func start() {
		midi.openInput(name: "Bluetooth")
		midi.openInput()
		midi.addListener(self)
	}

	func stop() {
		midi.closeAllInputs()
	}

	func receivedMIDINoteOn(noteNumber: MIDINoteNumber,
							velocity: MIDIVelocity,
							channel: MIDIChannel,
							portID: MIDIUniqueID? = nil,
							offset: MIDITimeStamp = 0) {
		DispatchQueue.main.async {
			self.data.noteOn = Int(noteNumber)
			self.data.velocity = Int(velocity)
			self.data.channel = Int(channel)
		}
	}

	func receivedMIDINoteOff(noteNumber: MIDINoteNumber,
							 velocity: MIDIVelocity,
							 channel: MIDIChannel,
							 portID: MIDIUniqueID? = nil,
							 offset: MIDITimeStamp = 0) {
		DispatchQueue.main.async {
			self.data.noteOff = Int(noteNumber)
			self.data.channel = Int(channel)
		}
	}

	func receivedMIDIController(_ controller: MIDIByte,
								value: MIDIByte,
								channel: MIDIChannel,
								portID: MIDIUniqueID? = nil,
								offset: MIDITimeStamp = 0) {
		print("controller \(controller) \(value)")
		data.controllerNumber = Int(controller)
		data.controllerValue = Int(value)
		data.channel = Int(channel)
	}

	func receivedMIDIAftertouch(_ pressure: MIDIByte,
								channel: MIDIChannel,
								portID: MIDIUniqueID? = nil,
								offset: MIDITimeStamp = 0) {
		print("received after touch")
		data.afterTouch = Int(pressure)
		data.channel = Int(channel)
	}

	func receivedMIDIAftertouch(noteNumber: MIDINoteNumber,
								pressure: MIDIByte,
								channel: MIDIChannel,
								portID: MIDIUniqueID? = nil,
								offset: MIDITimeStamp = 0) {
		print("recv'd after touch \(noteNumber)")
		data.afterTouchNoteNumber = Int(noteNumber)
		data.afterTouch = Int(pressure)
		data.channel = Int(channel)
	}

	func receivedMIDIPitchWheel(_ pitchWheelValue: MIDIWord,
								channel: MIDIChannel,
								portID: MIDIUniqueID? = nil,
								offset: MIDITimeStamp = 0) {
		print("midi wheel \(pitchWheelValue)")
		data.pitchWheelValue = Int(pitchWheelValue)
		data.channel = Int(channel)
	}

	func receivedMIDIProgramChange(_ program: MIDIByte,
								   channel: MIDIChannel,
								   portID: MIDIUniqueID? = nil,
								   offset: MIDITimeStamp = 0) {
		print("PC")
		data.programChange = Int(program)
		data.channel = Int(channel)
	}

	func receivedMIDISystemCommand(_ data: [MIDIByte],
								   portID: MIDIUniqueID? = nil,
								   offset: MIDITimeStamp = 0) {
		//        print("sysex")
	}

	func receivedMIDISetupChange() {
		// Do nothing
	}

	func receivedMIDIPropertyChange(propertyChangeInfo: MIDIObjectPropertyChangeNotification) {
		// Do nothing
	}

	func receivedMIDINotification(notification: MIDINotification) {
		// Do nothing
	}
}


// MARK: - PCM

struct PWMOscillatorData {
	var isPlaying: Bool = false
	var pulseWidth: AUValue = 0.5
	var frequency: AUValue = 440
	var amplitude: AUValue = 0.1
	var rampDuration: AUValue = 1
}

class PWMOscillatorConductor: ObservableObject, KeyboardDelegate {

	let engine = AudioEngine()

	func noteOn(note: MIDINoteNumber) {
		data.isPlaying = true
		data.frequency = note.midiNoteToFrequency()
	}

	func noteOff(note: MIDINoteNumber) {
		data.isPlaying = false
	}

	@Published var data = PWMOscillatorData() {
		didSet {
			if data.isPlaying {
				osc.start()
				osc.$pulseWidth.ramp(to: data.pulseWidth, duration: data.rampDuration)
				osc.$frequency.ramp(to: data.frequency, duration: data.rampDuration)
				osc.$amplitude.ramp(to: data.amplitude, duration: data.rampDuration)

			} else {
				osc.amplitude = 0.0
			}
		}
	}

	var osc = PWMOscillator()
	let plot: NodeOutputPlot

	init() {
		plot = NodeOutputPlot(osc)
		engine.output = osc
	}

	func start() {
		osc.amplitude = 0.2
		plot.start()

		do {
			try engine.start()
		} catch let err {
			Log(err)
		}
	}

	func stop() {
		data.isPlaying = false
		osc.stop()
		engine.stop()
	}
}


struct ShepardSynthView: View {
	@ObservedObject var midiConductor = MIDIMonitorConductor()
	@ObservedObject var pwmConductor = PWMOscillatorConductor()

    var body: some View {
		VStack {
			HStack {
				VStack {
					HStack {
						Text("Note On: \(midiConductor.data.noteOn == 0 ? "-" : "\(midiConductor.data.noteOn)")")
						Text("Velocity: \(midiConductor.data.velocity)")
					}
					HStack {
						Text("Note Off: \(midiConductor.data.noteOff == 0 ? "-" : "\(midiConductor.data.noteOff)")")
						Text("Channel: \(midiConductor.data.channel)")
					}
					HStack {
						Text("Controller: \(midiConductor.data.controllerNumber == 0 ? "-" : "\(midiConductor.data.controllerNumber)")")
						Text("Value: \(midiConductor.data.controllerValue == 0 ? "-" : "\(midiConductor.data.controllerValue)")")
					}
				}
			}.navigationBarTitle(Text("MIDI Monitor"))
			.onAppear {
				self.midiConductor.start()
			}
			.onDisappear {
				self.midiConductor.stop()
			}
			Spacer()
			Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
			Spacer()
			VStack {
				Text(self.pwmConductor.data.isPlaying ? "STOP" : "START").onTapGesture {
					self.pwmConductor.data.isPlaying.toggle()
				}
				ParameterSlider(text: "Pulse Width",
								parameter: self.$pwmConductor.data.pulseWidth,
								range: 0 ... 1).padding(5)
				ParameterSlider(text: "Frequency",
								parameter: self.$pwmConductor.data.frequency,
								range: 220...880).padding(5)
				ParameterSlider(text: "Amplitude",
								parameter: self.$pwmConductor.data.amplitude,
								range: 0 ... 1).padding(5)
				ParameterSlider(text: "Ramp Duration",
								parameter: self.$pwmConductor.data.rampDuration,
								range: 0...10).padding(5)

				KeyboardWidget(delegate: pwmConductor)

			}.navigationBarTitle(Text("PWM Oscillator"))
			.onAppear {
				self.pwmConductor.start()
			}
			.onDisappear {
				self.pwmConductor.stop()
			}
		}
    }
}

struct ShepardSynthView_Previews: PreviewProvider {
    static var previews: some View {
        ShepardSynthView()
    }
}
