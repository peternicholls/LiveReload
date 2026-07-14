# Phase 2 Idle CPU and Resource Lifecycle Evidence

**Result:** PASS

- Date: 2026-07-14
- Command: `scripts/verify-reload-idle.sh`
- Scope: one production `FSEventsFileEventSource` / `ProjectMonitor` and one
  production loopback `ReloadServer`, using a disposable workspace
- Warm-up: 30 seconds
- Sampling: 300 process CPU samples at one-second intervals
- Acceptance threshold: mean process CPU below 1%

## Measurement result

| Metric | Recorded value | Gate |
|---|---:|---|
| Samples | 300 | PASS — exactly 300 |
| Interval | 1 second | PASS |
| Mean process CPU | 0.0126% | PASS — below 1% |
| Peak process CPU | 0.0251% | Recorded |

The release-built probe measures its own process with `getrusage`. Each value
is the process user-plus-system CPU-time delta divided by the corresponding
`ContinuousClock` wall-time delta. The probe performs no per-sample console
output; it emits the complete series only after the five-minute window, so
recording does not perturb the measured process.

## Resource cleanup result

Before the idle sample, the probe completed three production start/stop cycles.
Each cycle established a ready protocol-7 WebSocket session, then verified:

- the monitor reached `stopped`;
- its scoped folder-access token released exactly once;
- stopping the server closed the ready client session, observed as peer EOF;
- the server reported `stopped` with no listening port; and
- a new listener immediately rebound the released loopback port.

After sampling, the active monitor and server were stopped and the idle
listener port was also rebound. Recorded totals were:

| Cleanup observation | Recorded value | Gate |
|---|---:|---|
| Repeated pre-sample cycles | 3 | PASS |
| Monitor stops, including post-sample cleanup | 4 | PASS |
| Scoped folder-access releases | 4 | PASS |
| Released listener port rebinds | 4 | PASS |
| Ready client sessions closed by server stop | 3 | PASS |

The workspace was created in the system temporary area and deleted after the
run. Its path, project identifiers, listener ports, peer addresses, source
contents, process identifier, and environment were not retained.

## Per-second CPU samples

```csv
sample,cpu_percent
1,0.0194
2,0.0165
3,0.0215
4,0.0157
5,0.0143
6,0.0167
7,0.0180
8,0.0126
9,0.0089
10,0.0102
11,0.0137
12,0.0167
13,0.0128
14,0.0088
15,0.0070
16,0.0104
17,0.0160
18,0.0127
19,0.0102
20,0.0180
21,0.0251
22,0.0143
23,0.0157
24,0.0146
25,0.0094
26,0.0080
27,0.0133
28,0.0137
29,0.0131
30,0.0089
31,0.0059
32,0.0109
33,0.0142
34,0.0150
35,0.0168
36,0.0150
37,0.0132
38,0.0073
39,0.0107
40,0.0151
41,0.0165
42,0.0130
43,0.0147
44,0.0143
45,0.0094
46,0.0096
47,0.0117
48,0.0157
49,0.0169
50,0.0161
51,0.0137
52,0.0122
53,0.0059
54,0.0058
55,0.0147
56,0.0160
57,0.0162
58,0.0191
59,0.0103
60,0.0136
61,0.0135
62,0.0117
63,0.0155
64,0.0120
65,0.0145
66,0.0210
67,0.0114
68,0.0177
69,0.0152
70,0.0104
71,0.0118
72,0.0143
73,0.0137
74,0.0123
75,0.0119
76,0.0125
77,0.0103
78,0.0154
79,0.0169
80,0.0086
81,0.0078
82,0.0070
83,0.0098
84,0.0093
85,0.0130
86,0.0098
87,0.0090
88,0.0123
89,0.0154
90,0.0175
91,0.0144
92,0.0117
93,0.0177
94,0.0201
95,0.0203
96,0.0151
97,0.0113
98,0.0140
99,0.0137
100,0.0121
101,0.0168
102,0.0122
103,0.0100
104,0.0111
105,0.0179
106,0.0121
107,0.0109
108,0.0090
109,0.0122
110,0.0104
111,0.0149
112,0.0123
113,0.0087
114,0.0108
115,0.0152
116,0.0136
117,0.0126
118,0.0090
119,0.0090
120,0.0083
121,0.0079
122,0.0128
123,0.0123
124,0.0139
125,0.0139
126,0.0119
127,0.0148
128,0.0165
129,0.0116
130,0.0124
131,0.0160
132,0.0100
133,0.0106
134,0.0115
135,0.0101
136,0.0116
137,0.0128
138,0.0123
139,0.0117
140,0.0097
141,0.0116
142,0.0093
143,0.0112
144,0.0129
145,0.0098
146,0.0094
147,0.0150
148,0.0136
149,0.0193
150,0.0089
151,0.0110
152,0.0151
153,0.0121
154,0.0100
155,0.0062
156,0.0092
157,0.0119
158,0.0150
159,0.0089
160,0.0133
161,0.0200
162,0.0137
163,0.0083
164,0.0075
165,0.0064
166,0.0054
167,0.0105
168,0.0131
169,0.0114
170,0.0155
171,0.0143
172,0.0106
173,0.0102
174,0.0110
175,0.0058
176,0.0071
177,0.0078
178,0.0125
179,0.0105
180,0.0085
181,0.0087
182,0.0113
183,0.0162
184,0.0106
185,0.0095
186,0.0095
187,0.0058
188,0.0155
189,0.0139
190,0.0200
191,0.0160
192,0.0138
193,0.0122
194,0.0100
195,0.0061
196,0.0079
197,0.0111
198,0.0097
199,0.0125
200,0.0105
201,0.0122
202,0.0193
203,0.0145
204,0.0102
205,0.0081
206,0.0147
207,0.0140
208,0.0129
209,0.0141
210,0.0189
211,0.0136
212,0.0112
213,0.0065
214,0.0089
215,0.0144
216,0.0153
217,0.0167
218,0.0109
219,0.0133
220,0.0149
221,0.0116
222,0.0111
223,0.0147
224,0.0123
225,0.0122
226,0.0116
227,0.0157
228,0.0096
229,0.0086
230,0.0078
231,0.0163
232,0.0185
233,0.0159
234,0.0132
235,0.0116
236,0.0198
237,0.0133
238,0.0101
239,0.0148
240,0.0159
241,0.0201
242,0.0110
243,0.0105
244,0.0139
245,0.0086
246,0.0080
247,0.0114
248,0.0139
249,0.0182
250,0.0172
251,0.0164
252,0.0200
253,0.0122
254,0.0050
255,0.0077
256,0.0136
257,0.0076
258,0.0082
259,0.0097
260,0.0104
261,0.0166
262,0.0096
263,0.0103
264,0.0121
265,0.0164
266,0.0172
267,0.0179
268,0.0144
269,0.0123
270,0.0102
271,0.0057
272,0.0083
273,0.0122
274,0.0142
275,0.0185
276,0.0124
277,0.0159
278,0.0202
279,0.0130
280,0.0048
281,0.0083
282,0.0114
283,0.0104
284,0.0147
285,0.0145
286,0.0135
287,0.0096
288,0.0084
289,0.0096
290,0.0103
291,0.0100
292,0.0147
293,0.0165
294,0.0157
295,0.0146
296,0.0170
297,0.0170
298,0.0068
299,0.0084
300,0.0074
```

