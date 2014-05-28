import org.eclipse.paho.client.mqttv3.internal.*;
import org.eclipse.paho.client.mqttv3.persist.*;
import org.eclipse.paho.client.mqttv3.internal.wire.*;
import org.eclipse.paho.client.mqttv3.internal.security.*;
import org.eclipse.paho.client.mqttv3.util.*;
import org.eclipse.paho.client.mqttv3.logging.*;
import org.eclipse.paho.client.mqttv3.*;

import processing.video.*;
import java.awt.Rectangle;

import java.util.Arrays;

// Constants
int nr_cols = 46;
int nr_rows = 20;
int darkness = 100;

// movie
//String movie_filename = "/home/fablab/Downloads/big_buck_bunny_480p_surround-fix.avi";
//String movie_filename = "/home/fablab/Downloads/Helicopter_DivXHT_ASP.divx";
//String movie_filename = "/home/fablab/Downloads/132905MadeSimpleRewilding-16x9.mp4";
//String movie_filename = "/home/fablab/Downloads/shrek-4-the-final-chapter_555_480x200.mp4";
//String movie_filename = "/home/fablab/Downloads/022666739-lipstick-kiss.mp4";
//String movie_filename = "/home/fablab/Downloads/matrix2_320x176.mpg";
//String movie_filename = "/home/fablab/dev/luzz/videos/Baaa.mp4";
String movie_filename = "/home/fablab/dev/luzz/videos/AREA_3001_TST_640_480.mp4";
Movie myMovie;

// Intermediary image
PImage intermed_image; 

//MQTT
byte[] payload = new byte[nr_cols * nr_rows * 3];
MqttClient client;
MqttMessage message;

void setup() 
{ 
  try {
      client = new MqttClient("tcp://localhost:1883", "pahomqttpublish_video");
      client.connect();
  } catch (MqttException e) {
      e.printStackTrace();
  }

  size(640, 480); 
  frameRate(30);
  myMovie = new Movie(this, movie_filename); 
  //myMovie.speed(4.0);
  myMovie.loop();
  
} 
 
void movieEvent(Movie myMovie) 
{ 
  myMovie.read();
  grab_and_send();
}
 
void draw() 
{ 
  //println("drawing");
  image(myMovie, 0,0, width, height);
}

void grab_and_send() {

  intermed_image = get();  
  intermed_image.resize(nr_cols, nr_rows);  
  tint(darkness);
  image(intermed_image, 0,0, nr_cols, nr_rows);
  //intermed_image = get();
  
  for (int i = 0; i < nr_rows; i++) {
    for (int j = 0; j < nr_cols; j++) {
      int loc = i*nr_cols + j;
      
      payload [loc*3    ] = byte (red   (intermed_image.pixels [loc])); // can also do with red = c >> 16 & 0xFF;
      payload [loc*3 + 1] = byte (blue  (intermed_image.pixels [loc]));
      payload [loc*3 + 2] = byte (green (intermed_image.pixels [loc]));
      
      //int maxValue = max (payload[loc*3], max (payload[loc*3+1], payload[loc*3+2]));
      //int sum = payload [loc*3] + payload [loc*3 + 1] + payload [loc*3 + 2];
      //if (sum != 0)
      //{
      //  //int norm = sqrt (payload [loc*3]*payload [loc*3] + payload [loc*3 + 1]*payload [loc*3 + 1] + payload [loc*3 + 2]*payload [loc*3 + 2]);
      //  if (sum != maxValue)
      //  {
      //    payload [loc*3    ] = (byte)((double)payload [loc*3    ]/sum*maxValue);
      //    payload [loc*3 + 1] = (byte)((double)payload [loc*3 + 1]/sum*maxValue);
      //    payload [loc*3 + 2] = (byte)((double)payload [loc*3 + 2]/sum*maxValue);
      //  }
      //}
    }
  }
  
  try {
      message = new MqttMessage();
      message.setPayload(payload);
      message.setQos(0);
      client.publish("/luzz/0", message); // Qos = 0
      //client.disconnect();
    } catch (MqttException e) {
      e.printStackTrace();
      print ("error");
  }
} 

// respond to mouse clicks as pause/play
boolean isPlaying = true;
void mousePressed() {
  if (isPlaying) {
    myMovie.pause();
    isPlaying = false;
  } else {
    myMovie.play();
    isPlaying = true;
  }
}
