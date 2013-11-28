/*
 * Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

function updateTooltip(e) {
	try {
		if (document.all) {
			if (document.documentElement && document.documentElement.scrollTop) { // Explorer 6 Strict
				x = document.documentElement.scrollLeft + window.event.x;
				y = document.documentElement.scrollTop + window.event.y;
			}
			else { // all other Explorers
				x = document.body.scrollLeft + window.event.x;
				y = document.body.scrollTop + window.event.y;
			}
		}
		else {
			x = e.pageX;
			y = e.pageY;
		}

		if (tooltip != null) {
			o = -70;
			ox = 15;
			var sx, sy;
			if (self.pageYOffset) { // all except Explorer
				sx = self.pageXOffset;
				sy = self.pageYOffset;
			}
			else if (document.documentElement && document.documentElement.scrollTop) { // Explorer 6 Strict
				sx = document.documentElement.scrollLeft;
				sy = document.documentElement.scrollTop;
			}
			else if (document.body) { // all other Explorers
				sx = document.body.scrollLeft;
				sy = document.body.scrollTop;
			}
			
			t = y + o + tooltip.offsetHeight;
			w = sy + document.body.clientHeight;
			if (t > w) {
				y = y - o - tooltip.offsetHeight;
			}
			else {
				y = y + o;
			}
			
			t = x + ox + tooltip.offsetWidth;
			w = sx + document.body.clientWidth;
			if (t > w) {
				x = x - ox - tooltip.offsetWidth;
			}
			else {
				x = x + ox;
			}
			
			if ((tooltip.style.top == '' || tooltip.style.top == 0) && (tooltip.style.left == '' || tooltip.style.left == 0))
			{
				tooltip.style.width = tooltip.offsetWidth + 'px';
				tooltip.style.height = tooltip.offsetHeight + 'px';
			}
			tooltip.style.left = x + "px";
			tooltip.style.top = y + "px";
			document.Show.MouseX.value = x;
			document.Show.MouseY.value = y;
		}
	} catch (error) { error = null; }
}

function showTooltip(id) {
	try {
		tooltip = document.getElementById(id);
		tooltip.style.display = "block";
	} catch (error) { error = null; }
}

function hideTooltip() {
	try {
		tooltip.style.display = "none";
	} catch (error) { error = null; }
}
