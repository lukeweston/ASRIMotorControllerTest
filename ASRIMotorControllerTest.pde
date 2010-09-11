/*

Test program for rocket throttle control avionics
Luke Weston, September 2010.
luke@lunarnumbat.org

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

*/


const int gearbox_ratio = 50;			// This is a fixed value, for that particular gearbox.
const int encoder_counts_per_revolution = 50;	// This is a fixed value, for the E5S-50-250-IEG encoder.
const int step_multiplier = 5;			// Number of encoder steps per clock tick, programmed into the R2020 EEPROM.
const float duty_cycle = 0.50;			// The duty cycle of the clock waveform. Let's just make it 50% for now.

const int valve_rotational_speed = 200;		// At least 70 RPM at the valve = 1 Hz = 90 degrees in 250 ms.
const int valve_dither_angle = 40;		// Valve dither rotation angle, in degrees.
const int number_of_dither_cycles = 40;

const float scaling_factor_50V = 0.06354;
const float scaling_factor_24V = 0.02786;

// Hardware pin numbers
const int directionPin = 3;
const int clockPin = 4;
const int ledPin = 9;

// Function prototypes
void serial_print_ADC_readings();
void valve_dither_loop();
void rotate_valve(boolean direction, int pulse_train_frequency, int pulse_train_duration);

int motor_dither_angle = valve_dither_angle * gearbox_ratio;						// The dither angle at the motor.
int motor_rotational_speed = valve_rotational_speed * gearbox_ratio;					// The rotational speed at the motor.
int motor_step_resolution = ((step_multiplier * 360) / encoder_counts_per_revolution);			// The angular resolution of one step, at the motor.
int number_of_dither_steps = (motor_dither_angle / motor_step_resolution);				// The number of clock steps in a dithering movement.
int encoder_counts_per_second = (encoder_counts_per_revolution * (motor_rotational_speed / 60));	// The number of encoder ticks per second that come back from the motor.
int clock_frequency = (encoder_counts_per_second / step_multiplier);					// The frequency of the clock pulses we need to generate.
int on_time_microseconds = (duty_cycle * (1000000 / clock_frequency));					// The period of the on part of the waveform, in microseconds.
int off_time_microseconds = ((1 - duty_cycle) * (1000000 / clock_frequency));				// The period of the off part of the waveform, in microseconds.

boolean valve_open = false;
int pulse_train_frequency = 1250;

void setup()
{                
	Serial.begin(9600);
	pinMode(directionPin, OUTPUT);
	pinMode(clockPin, OUTPUT);
        pinMode(ledPin, OUTPUT);
	digitalWrite(ledPin, HIGH);
	digitalWrite(directionPin, HIGH);
	digitalWrite(clockPin, HIGH);		// Let's take the clock waveform high initially.
	delay(1000);				// A little delay to let everything settle down.
}

void loop()                     
{
         if (!valve_open){
             delay(20);
             valve_dither_loop();
         }
         
        if (valve_open){
            delay(1000);
        }
        // 100 ms * 1250 Hz = 125 cycles = 90 degrees. 500 cycles = full revolution.
        rotate_valve(valve_open, pulse_train_frequency, 100);
        valve_open = !(valve_open);
        serial_print_ADC_readings();
}

void rotate_valve(boolean direction, int pulse_train_frequency, int pulse_train_duration)
{ 
    
    	if (direction)
      		digitalWrite(directionPin, HIGH);
    
	if (!direction)
      		digitalWrite(directionPin, LOW);
    // The tone function is handy here, to do the job easily using nice clean, simple code.
    	tone(clockPin, pulse_train_frequency, pulse_train_duration);
}

void valve_dither_loop()
{
	int i = 0, j = 0;
	digitalWrite(directionPin, HIGH);

      	// Initially, suppose that we start with the valve at 12 o'clock.
      	// We rotate it forwards to the 1 o'clock position. Let's call that 1 theta.
  
        /* Unfortunately the tone function does not seem to behave well with very short durations,
        therefore we need to generate the pulses manually. */

	for(i = 0; i < number_of_dither_steps; i++)
	{
		digitalWrite(clockPin, HIGH);
		delayMicroseconds(on_time_microseconds);
		digitalWrite(clockPin, LOW);
		delayMicroseconds(off_time_microseconds);
	}

        // Then we flip the direction, and rotate the valve back to the 11 o'clock position,
        //  that is, 2 theta of rotation. Then we loop through a 2 theta rotation, flipping
        // the direction bit each time. Then the motor oscillates backwards and forwards between
	// 11 o'clock and 1 o'clock.

	for(j = 0; j < number_of_dither_cycles; j++)
	{
        	// flip direction bit from its present state
        	digitalWrite(directionPin, !(digitalRead(directionPin)));

		for(i = 0; i < (2 * number_of_dither_steps); i++)
		{
			digitalWrite(clockPin, HIGH);
			delayMicroseconds(on_time_microseconds);
			digitalWrite(clockPin, LOW);
			delayMicroseconds(off_time_microseconds);
		}
	}
      
	digitalWrite(directionPin, LOW);  
      	for(i = 0; i < number_of_dither_steps; i++)
	{
		digitalWrite(clockPin, HIGH);
		delayMicroseconds(on_time_microseconds);
		digitalWrite(clockPin, LOW);
		delayMicroseconds(off_time_microseconds);
	}
}

void serial_print_ADC_readings()
{
	Serial.println("Valve position sensor 1: ");
	Serial.print(map(analogRead(2), 0, 1023, 0, 100));
	Serial.println("");

	Serial.println("Valve position sensor 2: ");
	Serial.print(map(analogRead(3), 0, 1023, 0, 100));
	Serial.println("");

	Serial.println("24 V bus voltage: ");
	Serial.print(analogRead(1) * scaling_factor_24V);
	Serial.println("");

	Serial.println("60 V bus voltage: ");
	Serial.print(analogRead(0) * scaling_factor_50V);
	Serial.println("");
}

