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
String images_dir_name = "/home/fablab/dev/luzz/images/LOGO/";
File images_dir = new File (images_dir_name);

// Load image names manually
String[] images_names = {"logo_2x2_WH_80H.png"};

PImage[] images = new PImage[images_names.length]; // Declare variable "a" of type PImage

MqttClient client;
MqttMessage message;

byte bgR = byte(0), bgG = byte(0), bgB = byte(0);  //replacement bytes for background
byte frR = byte(255), frG = byte(255), frB = byte(255);  //replacement bytes for front
byte thR = byte(200), thG = byte(240), thB = byte(240);  //Threshold variables --> all 3 larger than this value = background
int    hue1;
float  sine1;

int savedTime;
int totalTime = 50;  //100msec
int image_index = 0;
int img_size_height = 40; //20
int img_size_width = 92; //46

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
MyFrame frame0 = new MyFrame(0,19,0,45);  // top left don't make errors here: it wont work :)
MyFrame frame1 = new MyFrame(20,39,0,45); // bottom left above frame zero: (20,39,0,45);
MyFrame frame2 = new MyFrame(20,39,46,91); // bottom right
MyFrame frame3 = new MyFrame(0,19,46,91);  // top right
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
  
  size(img_size_width, img_size_height);
  // The image file must be in the data folder of the current sketch
  // to load successfully
  
  // Load the image into the program
 for (int i=0; i < images_names.length; i++)
  {
    println (images_names[i]);
    images[i] = loadImage(images_dir_name + images_names[i]);
    images[i].resize(img_size_width, img_size_height);
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
  byte tempR, tempG, tempB;
  
  for(int h = 0; h < frames.length; h++) {
    int loc_frame = 0;
    for (int i = frames[h].bottom; i < frames[h].top + 1; i++) {
      for (int j = frames[h].left; j < frames[h].right + 1; j++) {
        int loc_image = i * width + j;      
        tempR = byte(red(images[image_index].pixels[loc_image])); // can also do with red = c >> 16 & 0xFF;
        tempG = byte(green(images[image_index].pixels[loc_image]));
        tempB = byte(blue(images[image_index].pixels[loc_image]));
//        if ((tempR <= thR)) {
//          //front
//          frames[h].payload[loc_frame] = byte(frR);
//          frames[h].payload[loc_frame+1] = byte(frG);
//          frames[h].payload[loc_frame+2] = byte(frB);    
//        }
//        else{
//          //Background
//          frames[h].payload[loc_frame] = bgR;
//          frames[h].payload[loc_frame+1] = bgG;
//          frames[h].payload[loc_frame+2] = bgB;      
//        }
        frames[h].payload[loc_frame]=byte(((bgR-tempR)));
        frames[h].payload[loc_frame+1]=byte(((bgG-tempR)));
        frames[h].payload[loc_frame+2]=byte(((bgB-tempR)));

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

void calc_bg(){
  int r,g,b,i,bright,lo;

  // Fixed-point hue-to-RGB conversion.  'hue1' is an integer in the
  // range of 0 to 1535, where 0 = red, 256 = yellow, 512 = green, etc.
  // The high byte (0-5) corresponds to the sextant within the color
  // wheel, while the low byte (0-255) is the fractional part between
  // the primary/secondary colors.
  lo = hue1 & 255;
  switch((hue1 >> 8) % 6) {
  case 0:
    r = 255;
    g = lo;
    b = 0;
    break;
  case 1:
    r = 255 - lo;
    g = 255;
    b = 0;
    break;
  case 2:
    r = 0;
    g = 255;
    b = lo;
    break;
  case 3:
    r = 0;
    g = 255 - lo;
    b = 255;
    break;
  case 4:
    r = lo;
    g = 0;
    b = 255;
    break;
  default:
    r = 255;
    g = 0;
    b = 255 - lo;
    break;
  }

  // Resulting hue is multiplied by brightness in the range of 0 to 255
  // (0 = off, 255 = brightest).  Gamma corrrection (the 'pow' function
  // here) adjusts the brightness to be more perceptually linear.
  bright      = int(pow(0.5 + sin(sine1) * 0.5, 2.8) * 255.0);
  bright = 255;
  bgR = byte((r * bright) / 255);
  bgG = byte((g * bright) / 255);
  bgB = byte((b * bright) / 255);

  // Each pixel is slightly offset in both hue and brightness
  hue1   = (hue1 + 4) % 1536;;
  sine1 -= 0.3;

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
      calc_bg();
      
      println( "Image index " + image_index + " length " + images.length);  
      image_index++;
      image_index %= images_names.length;
    }
  }
}
