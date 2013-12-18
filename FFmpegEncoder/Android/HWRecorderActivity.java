/*
 * Copyright (c) 2013, David Brodsky. All rights reserved.
 *
 *	This program is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.
 *	
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *	
 *	You should have received a copy of the GNU General Public License
 *	along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

package com.example.ffmpegtest;

import com.example.ffmpegtest.recorder.HLSRecorder;
import com.example.ffmpegtest.recorder.LiveHLSRecorder;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Color;
import android.os.Bundle;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.animation.AnimationUtils;
import android.widget.Button;
import android.widget.TextSwitcher;
import android.widget.TextView;
import android.widget.ViewSwitcher.ViewFactory;

public class HWRecorderActivity extends Activity {
    private static final String TAG = "HWRecorderActivity";
    boolean recording = false;
    LiveHLSRecorder liveRecorder;
    
    TextView liveIndicator;
    String broadcastUrl;

    //GLSurfaceView glSurfaceView;
    //GlSurfaceViewRenderer glSurfaceViewRenderer = new GlSurfaceViewRenderer();
    LayoutInflater inflater;

    protected void onCreate (Bundle savedInstanceState){
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(R.layout.activity_hwrecorder);
        inflater = (LayoutInflater) this.getSystemService(LAYOUT_INFLATER_SERVICE);
        liveIndicator = (TextView) findViewById(R.id.liveLabel);
        //glSurfaceView = (GLSurfaceView) findViewById(R.id.glSurfaceView);
        //glSurfaceView.setRenderer(glSurfaceViewRenderer);
        
        LocalBroadcastManager.getInstance(this).registerReceiver(mMessageReceiver,
        	      new IntentFilter(LiveHLSRecorder.INTENT_ACTION));
    }

    @Override
    public void onPause(){
        super.onPause();
        //glSurfaceView.onPause();
    }

    @Override
    public void onResume(){
        super.onResume();
        //glSurfaceView.onResume();
    }
    
    @Override
    protected void onDestroy() {
      // Unregister since the activity is about to be closed.
      LocalBroadcastManager.getInstance(this).unregisterReceiver(mMessageReceiver);
      super.onDestroy();
    }

    public void onRecordButtonClicked(View v){
        if(!recording){
        	broadcastUrl = null;
        	
            try {
                liveRecorder = new LiveHLSRecorder(getApplicationContext());
                liveRecorder.startRecording(null);
                ((Button) v).setText("Stop Recording");
            } catch (Throwable throwable) {
                throwable.printStackTrace();
            }
        }else{
            liveRecorder.stopRecording();
            ((Button) v).setText("Start Recording");
        	liveIndicator.startAnimation(AnimationUtils.loadAnimation(this, R.anim.slide_to_left));
        }
        recording = !recording;
    }
    
    private BroadcastReceiver mMessageReceiver = new BroadcastReceiver() {
    	  @Override
    	  public void onReceive(Context context, Intent intent) {
    	    // Get extra data included in the Intent
    		if (LiveHLSRecorder.HLS_STATUS.LIVE ==  (LiveHLSRecorder.HLS_STATUS) intent.getSerializableExtra("status")){
    			broadcastUrl = intent.getStringExtra("url");
    			liveIndicator.startAnimation(AnimationUtils.loadAnimation(getApplicationContext(), R.anim.slide_from_left));
            	liveIndicator.setVisibility(View.VISIBLE);
    		}  
    	  }
    };
    
    public void onUrlLabelClick(View v){
    	if(broadcastUrl != null){
    		shareUrl(broadcastUrl);
    	}
    }
    
    private void shareUrl(String url) {
        Intent shareIntent = new Intent(Intent.ACTION_SEND);
        shareIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_WHEN_TASK_RESET);
        shareIntent.setType("text/plain");
        startActivity(Intent.createChooser(shareIntent, "Share Broadcast!"));
    }  

    /*
    static EGLContext context;

    public class GlSurfaceViewRenderer implements GLSurfaceView.Renderer{

        @Override
        public void onSurfaceCreated(GL10 gl, EGLConfig config) {
            Log.i(TAG, "GLSurfaceView created");
            context = EGL14.eglGetCurrentContext();
            if(context == EGL14.EGL_NO_CONTEXT)
                Log.e(TAG, "failed to get valid EGLContext");

           EGL14.eglMakeCurrent(EGL14.eglGetCurrentDisplay(), EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
        }

        @Override
        public void onSurfaceChanged(GL10 gl, int width, int height) {

        }

        @Override
        public void onDrawFrame(GL10 gl) {
        }
    }
    */

}