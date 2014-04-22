import org.eclipse.paho.client.mqttv3.internal.*;
import org.eclipse.paho.client.mqttv3.persist.*;
import org.eclipse.paho.client.mqttv3.internal.wire.*;
import org.eclipse.paho.client.mqttv3.internal.security.*;
import org.eclipse.paho.client.mqttv3.util.*;
import org.eclipse.paho.client.mqttv3.logging.*;
import org.eclipse.paho.client.mqttv3.*;

//import se.goransson.mqtt.*;

import java.util.Arrays;

// load image for directory
String images_dir_name = "/home/fablab/dev/luzz/images/NYAN/";
//String images_dir_name = "/home/fablab/dev/luzz/images/NYAN/";
File images_dir = new File (images_dir_name);
//String[] images_names = images_dir.list();

// Load image names manually
//String[] images_names = {"space_invaders_anim_1.png", "space_invaders_anim_2.png"};
//String[] images_names = {"nyan_cat-cropped.gif"};
String[] images_names = {"01.png", "02.png", "03.png", "04.png", "05.png", "06.png", "07.png", "08.png", "09.png", "10.png", "11.png", "12.png"};

PImage[] images = new PImage[images_names.length]; // Declare variable "a" of type PImage

MqttClient client;
MqttMessage message;

int savedTime;
int totalTime = 1200;
int image_index = 0;

class MyFrame {
    int bottom = 0;
    int left = 0;
    int right = 0;
    int top = 0;
    byte[] payload;
    
    public MyFrame(int bottom, int top, int left, int right) { 
      this.bottom = bottom;
      this.top = top;
      this.left = left;
      this.right = right;  
      this.payload = new byte[(top - bottom + 1) * (right - left + 1) * 3];      
    }
};

// init
MyFrame frame0 = new MyFrame(0,19,0,45);
MyFrame frame1 = new MyFrame(0,19,0,45);
MyFrame frame2 = new MyFrame(0,19,0,45);
MyFrame frame3 = new MyFrame(0,19,0,45);
MyFrame frame4 = new MyFrame(0,19,0,45);
MyFrame frame5 = new MyFrame(0,19,0,45);
MyFrame frame6 = new MyFrame(0,19,0,45);
MyFrame[] frames = {frame0, frame1, frame2, frame3, frame4, frame5, frame6};
 
void setup() {
  //println (sketchPath);
  try {
      client = new MqttClient("tcp://localhost:1883", "pahomqttpublish1");
      client.connect();
    } catch (MqttException e) {
      e.printStackTrace();
      exit();
    }
  
  //MqttMessage message = new MqttMessage();
  //message.setPayload("A single message".getBytes());
  //client.publish("pahodemo/test", message);
  //client.disconnect();

  colorMode(RGB, 255);
  
  size(46, 20);
  // The image file must be in the data folder of the current sketch
  // to load successfully
  
  // Load the image into the program
  for (int i=0; i < images_names.length; i++)
  {
    println (images_names[i]);
    images[i] = loadImage(images_dir_name + images_names[i]);
  }
  //filter(THRESHOLD);
  
  // used for timing the animation
  savedTime = millis();
  draw(0);
  noLoop();
}

void draw() {
  draw(image_index);
}

void draw(int image_index) {
  // Displays the image at its actual size at point (0,0)
  image(images[image_index], 0, 0);
  images[image_index].loadPixels();
  println("redraw:" + image_index);
}

void grab_and_send() {
  
  for(int h = 0; h < frames.length; h++) {
    int loc_frame = 0;
    for (int i = frames[h].bottom; i < frames[h].top + 1; i++) {
      for (int j = frames[h].left; j < frames[h].right + 1; j++) {
        int loc_image = i * width + j;      
        frames[h].payload[loc_frame] = byte(red(images[image_index].pixels[loc_image])); // can also do with red = c >> 16 & 0xFF;
        frames[h].payload[loc_frame+1] = byte(green(images[image_index].pixels[loc_image]));
        frames[h].payload[loc_frame+2] = byte(blue(images[image_index].pixels[loc_image]));
        loc_frame += 3;
      }
    }
  
    //printArray(payload);
    //mqtt.publish("/luzz/1", Arrays.toString(payload));
    
    // Calculate how much time has passed
    
    try {
      message = new MqttMessage();
      message.setPayload(frames[h].payload);
      message.setQos(0);
      //println(h);
      client.publish("/luzz/" + h, message); // Qos = 0
      print("publishing image " + image_index + " to /luzz/" + h);
      //client.disconnect();
    }
    catch (MqttException e) {
      e.printStackTrace();
      print ("error");
    }
  }
}

void mousePressed() {
  int passedTime;
  println("Started...");
  while(true) {  
    // Calculate how much time has passed
    passedTime = millis() - savedTime;
    // Has x seconds passed?
    if (passedTime > totalTime) {
      savedTime = millis(); // Save the current time to restart the timer!
      println ("Passed: " + passedTime);
      
      // Ask to redraw it on screen
      //draw(image_index);
      redraw();
      
      // send image via mqtt
      grab_and_send();
      
      println( "Image index " + image_index + " length " + images.length);  
      image_index++;
      image_index %= images_names.length;
    }
  }
}
