import glob
import os
run = os.system  # convenience alias


files = glob.glob('*.mp4')
out_files = []

n = 0
for file in files:
    out_file = "out-{0}.ts".format(n)
    out_files.append(out_file)
    full_command = "ffmpeg -i {0} -f mpegts -vcodec copy -acodec copy -vbsf h264_mp4toannexb {1}".format(file, out_file)
    run(full_command)
    n += 1

out_file_concat = ''
for out_file in out_files:
    out_file_concat += ' {0} '.format(out_file)

cat_command = 'cat {0} > full.ts'.format(out_file_concat)
print cat_command
run(cat_command)
run("ffmpeg -i full.ts -f mp4 -vcodec copy -acodec copy -absf aac_adtstoasc full.mp4")
