// https://github.com/onformative/ScreenCapturer/issues/2
// mixed with out own code
import org.eclipse.paho.client.mqttv3.internal.*;
import org.eclipse.paho.client.mqttv3.persist.*;
import org.eclipse.paho.client.mqttv3.internal.wire.*;
import org.eclipse.paho.client.mqttv3.internal.security.*;
import org.eclipse.paho.client.mqttv3.util.*;
import org.eclipse.paho.client.mqttv3.logging.*;
import org.eclipse.paho.client.mqttv3.*;
import java.util.Arrays;

SimpleScreenCapture simpleScreenCapture;
MqttClient client;
MqttMessage message;

int SIZE_ROWS = 40;
int SIZE_COLS = 92;
int OFFSET_X = 500;
int OFFSET_Y = 500;

PImage[] images = new PImage[1];

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
MyFrame frame0 = new MyFrame(0,39,0,45);
MyFrame frame1 = new MyFrame(0,39,46,91);
MyFrame frame2 = new MyFrame(0,19,0,45);
MyFrame frame3 = new MyFrame(0,19,0,45);
MyFrame frame4 = new MyFrame(0,19,0,45);
MyFrame frame5 = new MyFrame(0,19,0,45);
MyFrame frame6 = new MyFrame(0,19,0,45);
// MyFrame[] frames = {frame0, frame1, frame2, frame3, frame4, frame5, frame6};
MyFrame[] frames = {frame0, frame1}; 

void setup() {
  colorMode(RGB, 255);
  frameRate(5);
  size(SIZE_COLS, SIZE_ROWS);
  simpleScreenCapture = new SimpleScreenCapture();

  try {
    client = new MqttClient("tcp://localhost:1883", "pahomqttpublish1");
    client.connect();
  } catch (MqttException e) {
    e.printStackTrace();
    exit();
  }

}

void draw() {
  images[0] = simpleScreenCapture.get();
  image(images[0], 0, 0, width, height);
  // send image via mqtt
  grab_and_send();
}

void grab_and_send() {
  int image_index = 0;
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

//////////////////////// the simpleScreenCapturer
import java.awt.Robot;
import java.awt.Rectangle;
import java.awt.AWTException;

class SimpleScreenCapture {
  Robot robot;
  PImage screenshot;
  
  SimpleScreenCapture() {
    try {
      robot = new Robot();
    }
    catch (AWTException e) {
      println(e);
    }
  }
  
  PImage get() {
    screenshot = new PImage(robot.createScreenCapture(new Rectangle(OFFSET_X, OFFSET_Y, width, height)));
    return screenshot;
  }
}
////////////////////////
