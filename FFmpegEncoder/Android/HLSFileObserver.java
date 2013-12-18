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

import java.io.File;

import android.os.FileObserver;

/**
 * A FileObserver that listens for actions
 * specific to the creation of an HLS stream
 * e.g: A .ts segment is written 
 * or a .m3u8 manifest is modified
 * @author davidbrodsky
 *
 */
public class HLSFileObserver extends FileObserver{
	
	private static final String M3U8_EXT = "m3u8";
	private static final String TS_EXT = "ts";
	String targetDir;
	
	private HLSCallback callback;
	
	public interface HLSCallback{
		public void onSegmentComplete(String path);
		public void onManifestUpdated(String path);
	}
	
	/**
	 * Begin observing the given path for changes
	 * to .ts and .m3u8 files
	 * @param path the absolute path to observe.
	 * @param callback a callback to be notified when HLS files are modified
	 */
	public HLSFileObserver(String path, HLSCallback callback){
		super(path, CLOSE_WRITE);
		this.callback = callback;
		targetDir = path;
	}

	@Override
	public void onEvent(int event, String path) {
		String ext = path.substring(path.lastIndexOf('.') + 1);
		if(ext.compareTo(M3U8_EXT) == 0){
			callback.onManifestUpdated(targetDir + File.separator + path);
		}else if(ext.compareTo(TS_EXT) == 0){
			callback.onSegmentComplete(targetDir + File.separator + path);
		}
	}

}
