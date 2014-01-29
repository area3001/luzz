import org.eclipse.paho.client.mqttv3.internal.*;
import org.eclipse.paho.client.mqttv3.persist.*;
import org.eclipse.paho.client.mqttv3.internal.wire.*;
import org.eclipse.paho.client.mqttv3.internal.security.*;
import org.eclipse.paho.client.mqttv3.util.*;
import org.eclipse.paho.client.mqttv3.logging.*;
import org.eclipse.paho.client.mqttv3.*;

//import se.goransson.mqtt.*;

import java.util.Arrays;

PImage img;  // Declare variable "a" of type PImage
MqttClient client;
  
void setup() {
  try {
      client = new MqttClient("tcp://localhost:1883", "pahomqttpublish1");
      client.connect();
    } catch (MqttException e) {
      e.printStackTrace();
    }
  
  //MqttMessage message = new MqttMessage();
  //message.setPayload("A single message".getBytes());
  //client.publish("pahodemo/test", message);
  //client.disconnect();

  colorMode(RGB, 255);
  
  size(46, 20);
  // The image file must be in the data folder of the current sketch 
  // to load successfully
  img = loadImage("/home/pave/Dropbox/Area3001/projects/LEDstrips/space_invaders.png");  // Load the image into the program  
  image(img, 0, 0);
  img.loadPixels();
}

void draw() {
  // Displays the image at its actual size at point (0,0)
  byte[] payload = new byte[width * height * 3];
  
  for (int i = 0; i < height; i++) {
    for (int j = 0; j < width; j++) {
      int loc = i*j + j;
      payload[loc*3] = byte(red(img.pixels[loc])); // can also do with red = c >> 16 & 0xFF;
      payload[loc*3+1] = byte(green(img.pixels[loc])); 
      payload[loc*3+2] = byte(blue(img.pixels[loc])); 
    }
  }
  //printArray(payload);
  //mqtt.publish("/luzz/1", Arrays.toString(payload));
  
  try {
      MqttMessage message = new MqttMessage();
      message.setPayload(payload);
      client.publish("/luzz/0", message);
      //client.disconnect();  
    } catch (MqttException e) {
      e.printStackTrace();
      print ("error");
    }
}

