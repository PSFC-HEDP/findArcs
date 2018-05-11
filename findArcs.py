# findArcs.py

# quick and dirty script to get arcs from accelerator camera
# 2018/05 Graeme Sutcliffe

# acquire movie
# extract frames
# find 1-2 frames with arc
# find splicing line (look at image brightness) from rolling shutter
# splice two images
# overlay on the background image... to be done later

from __future__ import print_function
import sys
import os
import imageio
import numpy as np

if len(sys.argv) < 2:
	print('Usage python ./findFrames.py <filename>')
	sys.exit()

# set it up so it can be run from a different directory
destDir,movieFile = os.path.split(sys.argv[1])
print('destination:',os.path.join(destDir,'{:s}_{:d}.png'.format(movieFile.split('.')[-2],1)))
assert len(destDir) == 0 or os.path.exists(destDir)

reader = imageio.get_reader(os.path.join(destDir,movieFile))#,fps=30/3.)
fps = reader.get_meta_data()['fps']
print('fps:',fps)

MAGIC_EVENT_RATIO = 1.05
MAGIC_DUPLICATE_RATIO = 1.0001

def isEvent(brightness):
	return brightness[-1] > MAGIC_EVENT_RATIO * np.average(brightness)

def isDuplicate(brightness):
	return (brightness[-1] < MAGIC_DUPLICATE_RATIO * brightness[-2] and \
			brightness[-1] > brightness[-2] / MAGIC_DUPLICATE_RATIO)
	
def spliceImages(im1,im2):
	imResult = np.maximum(im1,im2)
	return imResult

eventList = []
eventLastLoop = False
currentEventList = []
inds=[]
brightness=[]
for i,im in enumerate(reader):
	if i%100 == 0: 
		print('Frame',i) # for sanity
	inds.append(i)
	b = np.sum(im)*1.0/np.size(im)/256./3.
	brightness.append(b)	# build brighness list (helpful for arc identification
	
	# identify event
	if isEvent(brightness): # we have an event
		# reject duplicates
		if not isDuplicate(brightness):
			print('Arc at frame',i)
			# make eventFrameDict
			eventFrameDict = {'i':i,'image':im,'b':brightness[-1]}
			# add to current event
			currentEventList.append(eventFrameDict)
			# make sure the next iteration knows previous loop is event
			eventLastLoop = True
	
	elif eventLastLoop: # no longer in an event, but last loop was an event
		eventList.append(currentEventList)
		currentEventList = []
		eventLastLoop = False

for ai,e in enumerate(eventList):
	print('Arc at: {:0.1f} s'.format(e[0]['i']/fps))
	
	if len(e) == 1:		#if less than two pick, the one!
		splicedIm = e[0]['image']
	elif len(e) == 2:	# combine the two images of the event
		splicedIm = spliceImages(e[0]['image'],e[1]['image'])
	else:	# if more than two, pick brightest two
		pass
	
	imageio.imwrite(os.path.join(destDir,'{:s}_{:d}.png'.format(movieFile.split('.')[-2],1)),splicedIm)
