// Anime4K_Upscale_Denoise_CNN_x2_S
// 移植自 https://github.com/bloc97/Anime4K/blob/master/glsl/Upscale%2BDenoise/Anime4K_Upscale_Denoise_CNN_x2_S.glsl

//!MAGPIE EFFECT
//!VERSION 2
//!OUTPUT_WIDTH INPUT_WIDTH * 2
//!OUTPUT_HEIGHT INPUT_HEIGHT * 2


//!TEXTURE
Texture2D INPUT;

//!TEXTURE
//!WIDTH INPUT_WIDTH
//!HEIGHT INPUT_HEIGHT
//!FORMAT R16G16B16A16_FLOAT
Texture2D tex1;

//!TEXTURE
//!WIDTH INPUT_WIDTH
//!HEIGHT INPUT_HEIGHT
//!FORMAT R16G16B16A16_FLOAT
Texture2D tex2;

//!SAMPLER
//!FILTER POINT
SamplerState sam;

//!SAMPLER
//!FILTER LINEAR
SamplerState sam1;


//!PASS 1
//!DESC Conv-4x3x3x3
//!IN INPUT
//!OUT tex1
//!BLOCK_SIZE 16
//!NUM_THREADS 64

float4 A4KS1(float3 src[4][4], int i, int j) {
	float4 result = mul(src[i - 1][j - 1], float3x4(6.5515305e-05, 0.09565814, -0.0022499533, 0.14627136, -0.0065872427, 0.1441769, 0.17772098, 0.16298898, 0.03727593, 0.02010636, 0.013131043, 0.07891907));
	result += mul(src[i - 1][j], float3x4(0.029612074, -0.01204274, 0.07698074, 0.3855172, 0.0045466167, -0.0859741, 0.26930287, 0.67549795, -0.036623597, 0.051749162, -0.04714053, 0.16092339));
	result += mul(src[i - 1][j + 1], float3x4(-0.030328937, -0.15884648, 0.0082092965, -0.05052196, 0.041409027, -0.23017453, 0.31568366, 0.05136558, -0.0106390705, -0.12503141, -0.07030922, -0.08512375));
	result += mul(src[i][j - 1], float3x4(0.059616547, -0.12322959, 0.058520414, -0.039292034, 0.08059592, -0.22441447, 0.15380386, -0.17675085, -0.009270574, 0.034731936, -0.048767723, 0.025933916));
	result += mul(src[i][j], float3x4(-0.4495482, 0.37551787, -0.4227873, -0.4890034, -0.9007091, 0.7524192, -1.271679, -0.68366605, -0.07302573, 0.09378561, 0.010367829, -0.24593607));
	result += mul(src[i][j + 1], float3x4(0.12684742, -0.11042779, 0.01793761, 0.06982078, 0.12901784, -0.10123104, -0.2129385, -0.15062876, 0.019824497, -0.015181707, 0.070795976, 0.13549626));
	result += mul(src[i + 1][j - 1], float3x4(-0.036070887, -0.2733308, 0.05836442, -0.06817092, -0.08980838, -0.514616, 0.2965783, 0.103823625, -0.015213521, -0.16376303, 0.0017071419, -0.0922202));
	result += mul(src[i + 1][j], float3x4(-0.053406045, 0.011273207, -0.05544644, 0.09432561, -0.04143601, -0.0783786, -0.39899537, 0.040322974, -0.046442945, 0.052499074, 0.03397099, 0.05516481));
	result += mul(src[i + 1][j + 1], float3x4(0.35976252, 0.197882, 0.031213427, -0.02211337, 0.7940331, 0.327452, 0.30120966, 0.03181121, 0.13782893, 0.060073618, -0.00940469, -0.0358819));
	result += float4(-0.004601904, -0.0030944077, 0.14569537, -0.016794242);
	return result;
}

void Pass1(uint2 blockStart, uint3 threadId) {
	uint2 gxy = (Rmp8x8(threadId.x) << 1) + blockStart;
	uint2 inputSize = GetInputSize();
	if (gxy.x >= inputSize.x || gxy.y >= inputSize.y) {
		return;
	}

	float2 inputPt = GetInputPt();

	float3 src[4][4];
	[unroll]
	for (uint i = 0; i < 3; i += 2) {
		[unroll]
		for (uint j = 0; j < 3; j += 2) {
			float2 tpos = (gxy + uint2(i, j)) * inputPt;
			const float4 sr = INPUT.GatherRed(sam, tpos);
			const float4 sg = INPUT.GatherGreen(sam, tpos);
			const float4 sb = INPUT.GatherBlue(sam, tpos);

			// w z
			// x y
			src[i][j] = float3(sr.w, sg.w, sb.w);
			src[i][j + 1] = float3(sr.x, sg.x, sb.x);
			src[i + 1][j] = float3(sr.z, sg.z, sb.z);
			src[i + 1][j + 1] = float3(sr.y, sg.y, sb.y);
		}
	}

	tex1[gxy] = A4KS1(src, 1, 1);
	++gxy.x;
	tex1[gxy] = A4KS1(src, 2, 1);
	++gxy.y;
	tex1[gxy] = A4KS1(src, 2, 2);
	--gxy.x;
	tex1[gxy] = A4KS1(src, 1, 2);
}


//!PASS 2
//!DESC Conv-4x3x3x8
//!IN tex1
//!OUT tex2
//!BLOCK_SIZE 16
//!NUM_THREADS 64

float4 A4KS2(float4 src[4][4], int i, int j) {
	// [ a, d, g ]
	// [ b, e, h ]
	// [ c, f, i ]

	float4 result = mul(max(src[i - 1][j - 1], 0), float4x4(-0.103708945, -0.050891697, -0.2067834, -0.033582103, -0.08676132, 0.15528207, -0.10070597, -0.13641205, 0.030959459, 0.12798834, -0.058627255, -0.008511715, 0.023304658, -0.027084433, 0.120355256, -0.023104342));
	result += mul(max(src[i - 1][j], 0), float4x4(0.0550643, -0.26851672, 0.11073926, 0.21989855, 0.012853378, 0.028077757, 0.073306665, -0.04551125, 0.16005373, -0.018154016, -0.12347146, -0.07590073, -0.10193998, 0.084696375, 0.04041413, -0.030883553));
	result += mul(max(src[i - 1][j + 1], 0), float4x4(-0.04816972, 0.0804637, 0.0071406, -0.08482986, 0.11176785, 0.060121994, -0.047804814, -0.036170192, 0.01989302, -0.12537469, -0.16283676, 0.19132937, -0.052577138, -0.005143432, 0.045614418, 0.04198543));
	result += mul(max(src[i][j - 1], 0), float4x4(-0.33660156, 0.036350835, -0.4623589, -0.04140598, 0.2436438, -0.044735093, 0.20876355, -0.004252532, 0.81046224, -0.18550895, 0.32743093, 0.109012894, -0.34675312, -0.03464997, -0.09489919, -0.07961427));
	result += mul(max(src[i][j], 0), float4x4(-0.08862038, -0.8168393, 0.03584266, 0.32159033, 0.06634099, 0.2985745, -0.18204363, -0.016070427, 0.35503992, 1.1388919, 0.16171643, -0.63834023, -0.0037699202, -0.27919513, -0.20949292, 0.03270466));
	result += mul(max(src[i][j + 1], 0), float4x4(0.021701936, -0.04537874, -0.05514495, 0.23225744, 0.024968185, 0.1816845, 0.03485249, -0.28249854, -0.37759346, -0.3225813, 0.021595621, 0.17104608, -0.0044055753, 0.01621266, -0.015169225, 0.08956203));
	result += mul(max(src[i + 1][j - 1], 0), float4x4(-0.033255238, -0.110517226, 0.10664505, 0.019566126, -0.0695305, 0.059743922, -0.19161415, -0.024217626, -0.08578889, -0.16358584, -0.23050265, -0.004697784, -0.060790297, 0.1174991, 0.08205285, -0.011846926));
	result += mul(max(src[i + 1][j], 0), float4x4(0.6119327, 0.0791928, -0.118774265, 0.42233524, -0.16248553, -0.017692063, 0.13530938, -0.3207985, -0.147722, -0.24525681, 0.05243329, -0.38583818, 0.5147888, -0.072632834, -0.6014986, 0.26713687));
	result += mul(max(src[i + 1][j + 1], 0), float4x4(0.23735437, -0.032110002, 0.17445332, -0.3272264, 0.020623574, 0.26734766, -0.16806662, 0.0796467, -0.34921628, 0.016648084, -0.14200358, 0.59190625, 0.13177821, 0.11139572, -0.14972521, -0.16784541));
	result += mul(max(-src[i - 1][j - 1], 0), float4x4(-0.047283772, -0.003196778, 0.44890094, 0.14619343, -0.17113213, -0.068454474, 0.07681565, -0.04306807, -0.0022641511, -0.20954822, 0.0344229, 0.014815744, -0.010632933, 0.13355999, -0.0860752, -0.069001146));
	result += mul(max(-src[i - 1][j], 0), float4x4(0.11664345, 0.099102855, 0.1642523, 0.047408774, 0.038490184, 0.16064398, -0.08694127, -0.2149453, -0.1413128, -0.06531084, -0.10105762, 0.19743964, 0.10458527, -0.04133969, 0.1425028, -0.01328308));
	result += mul(max(-src[i - 1][j + 1], 0), float4x4(0.0138432095, -0.20053013, 0.079355195, 0.273772, 0.05484276, 0.13891658, 0.16240036, -0.25245088, 0.011192391, 0.104164094, 0.08112111, -0.250435, -0.0559613, -0.031029798, -0.015725998, 0.09240792));
	result += mul(max(-src[i][j - 1], 0), float4x4(0.18754779, -0.33171803, 0.34917468, 0.29074225, -0.37954012, 0.20898043, -0.24973525, -0.13707505, -0.31585664, 0.13607393, -0.29118514, 0.015055187, 0.18549949, -0.06351915, 0.2823401, -0.00019733967));
	result += mul(max(-src[i][j], 0), float4x4(0.10060476, 0.2883022, -0.15810104, -0.041112892, 0.31050095, 0.18517002, 0.020033397, -0.35919502, -0.17903808, -0.43506318, -0.14783014, 0.20092726, -0.002020754, 0.13320895, 0.040995706, 0.052643474));
	result += mul(max(-src[i][j + 1], 0), float4x4(-0.014892139, 0.005828587, 0.044784732, -0.27272886, 0.21069369, 0.044396695, -0.03411123, 0.031441864, 0.17224072, 0.1708587, -0.00729118, -0.13070418, -0.19128975, -0.09342688, -0.051133234, -0.089075714));
	result += mul(max(-src[i + 1][j - 1], 0), float4x4(0.08799108, 0.04157696, -0.15010124, 0.26832178, -0.0040120087, 0.040308744, 0.17632529, -0.09464763, 0.07786305, 0.038288828, 0.40799135, 0.037377868, -0.049877923, -0.25080636, 0.00068664295, 0.0013101585));
	result += mul(max(-src[i + 1][j], 0), float4x4(0.0353459, -0.21445732, 0.112647906, -0.3513759, 0.16887255, 0.3224789, -0.17073384, 0.10875396, 0.18919177, 0.14288992, 0.07364533, 0.20205943, -0.34363645, -0.3520186, 0.6763608, -0.19051236));
	result += mul(max(-src[i + 1][j + 1], 0), float4x4(-0.032245517, 0.039594565, -0.11825768, 0.16509856, 0.11749939, -0.005166539, 0.10740687, -0.3794017, 0.12722437, 0.14066173, 0.08025407, -0.34773758, -0.027300838, -0.08963159, 0.29774833, 0.053532287));
	result += float4(0.022899346, 0.033619333, 0.030674957, -0.017047008);
	return result;
}

void Pass2(uint2 blockStart, uint3 threadId) {
	uint2 gxy = (Rmp8x8(threadId.x) << 1) + blockStart;
	uint2 inputSize = GetInputSize();
	if (gxy.x >= inputSize.x || gxy.y >= inputSize.y) {
		return;
	}
	float2 inputPt = GetInputPt();

	float4 src[4][4];
	[unroll]
	for (uint i = 0; i < 3; i += 2) {
		[unroll]
		for (uint j = 0; j < 3; j += 2) {
			float2 tpos = (gxy + uint2(i, j)) * inputPt;
			const float4 sr = tex1.GatherRed(sam, tpos);
			const float4 sg = tex1.GatherGreen(sam, tpos);
			const float4 sb = tex1.GatherBlue(sam, tpos);
			const float4 sa = tex1.GatherAlpha(sam, tpos);

			// w z
			// x y
			src[i][j] = float4(sr.w, sg.w, sb.w, sa.w);
			src[i][j + 1] = float4(sr.x, sg.x, sb.x, sa.x);
			src[i + 1][j] = float4(sr.z, sg.z, sb.z, sa.z);
			src[i + 1][j + 1] = float4(sr.y, sg.y, sb.y, sa.y);
		}
	}

	tex2[gxy] = A4KS2(src, 1, 1);
	++gxy.x;
	tex2[gxy] = A4KS2(src, 2, 1);
	++gxy.y;
	tex2[gxy] = A4KS2(src, 2, 2);
	--gxy.x;
	tex2[gxy] = A4KS2(src, 1, 2);
}


//!PASS 3
//!DESC Conv-4x3x3x8
//!IN tex2
//!OUT tex1
//!BLOCK_SIZE 16
//!NUM_THREADS 64

float4 A4KS3(float4 src[4][4], int i, int j) {
	// [ a, d, g ]
	// [ b, e, h ]
	// [ c, f, i ]

	float4 result = mul(max(src[i - 1][j - 1], 0), float4x4(-0.0714004, -0.0545495, -0.050848898, 0.04724593, 0.2214181, 0.26353878, 0.07314053, -0.18771721, 0.06282607, -0.03720548, 0.020577375, -0.08951135, 0.40820515, 0.012179098, 0.52947706, -0.48448065));
	result += mul(max(src[i - 1][j], 0), float4x4(0.10311368, -0.10970221, 0.07008208, -0.07143153, 0.073753305, 0.03786335, -0.4312538, -0.17680745, -0.15527713, -0.06711554, -0.21828765, 0.27252844, -0.0025433605, 0.31595528, -0.06065309, 0.059542265));
	result += mul(max(src[i - 1][j + 1], 0), float4x4(-0.036736265, 0.08704119, -0.06530063, 0.04546563, 0.010335546, -0.040761005, -0.021500558, 0.104531065, 0.094652064, -0.05088704, 0.14768088, -0.08585825, 0.057680476, 0.09885713, 0.18074304, -0.14277679));
	result += mul(max(src[i][j - 1], 0), float4x4(-0.04810641, -0.01735864, -0.06405213, 0.04889552, -0.011552542, -0.04617259, 0.023976233, 0.27587202, -0.117965676, -0.07052052, -0.030583147, -0.036600694, -0.08542387, -0.053850796, 0.27242282, -0.73792183));
	result += mul(max(src[i][j], 0), float4x4(-0.1340838, 0.1256252, -0.040528856, 0.13554344, -0.13733707, -0.14641404, 0.42666963, -0.4933124, -0.34908, 0.054332364, -0.2768947, 0.44689894, 0.42182985, -0.027279109, -0.17136064, -0.009496184));
	result += mul(max(src[i][j + 1], 0), float4x4(0.075086355, -0.025501372, 0.02172236, -0.052761186, -0.055753034, -0.028023237, -0.08829973, 0.14333946, 0.062496934, 0.034493748, 0.17640088, -0.084869936, 0.21283653, 0.1184779, 0.0016387368, -0.1498814));
	result += mul(max(src[i + 1][j - 1], 0), float4x4(0.054841094, 0.040639404, -0.025044259, -0.071105786, -0.07473824, -0.04719771, 0.016553668, -0.10028357, 0.009365985, -0.0133521445, 0.022320358, -0.09318326, 0.17342545, 0.19281831, 0.16737404, -0.09583887));
	result += mul(max(src[i + 1][j], 0), float4x4(-0.03950585, 0.091417804, -0.021395942, 0.08735149, -0.029363452, -0.04763804, -0.1430701, 0.15344201, -0.006604305, 0.05897304, -0.13595524, 0.083323576, 0.008187976, 0.12946083, 0.14983748, -0.08178542));
	result += mul(max(src[i + 1][j + 1], 0), float4x4(-0.00046765045, -0.07914878, 0.03529457, -0.007752294, -0.10084779, -0.1531338, -0.1408283, 0.20638838, 0.01466853, -0.059309185, -0.11161097, 0.08481583, 0.090416916, 0.081118226, 0.08677104, -0.20095336));
	result += mul(max(-src[i - 1][j - 1], 0), float4x4(0.3200496, -0.049090706, 0.11554867, -0.11949655, -0.18064958, 0.0012254696, -0.032284267, 0.00076361356, -0.13239916, -0.13838826, -0.20345089, 0.00692921, -0.2271236, -0.07132879, -0.097703665, 0.29881954));
	result += mul(max(-src[i - 1][j], 0), float4x4(0.4095371, 0.3008338, -0.43109173, -0.495734, 0.15016843, -0.3890023, 1.0669806, -0.20876339, -0.32241493, -0.10387533, -0.018227777, 0.1349976, -0.0019588785, -0.19263229, 0.38952798, 0.08135965));
	result += mul(max(-src[i - 1][j + 1], 0), float4x4(0.01517036, -0.51562387, -0.13939962, -0.23287989, 0.09597558, 0.017624658, 0.16989397, -0.09395267, -0.29612765, 0.11843327, -0.07493133, 0.14523852, 0.040488124, 0.016568637, 0.10204776, -0.13137013));
	result += mul(max(-src[i][j - 1], 0), float4x4(-0.1512155, -0.12732185, 0.08002965, 0.024762904, 0.05106389, 0.011125884, -0.043196492, -0.17617282, 0.09791206, 0.120643355, 0.075500526, 0.10948051, 0.04969893, -0.20776172, -0.06905779, -0.20245977));
	result += mul(max(-src[i][j], 0), float4x4(-0.41836104, -0.82896453, -0.20962712, 0.7804863, 0.17322528, 0.53994787, -0.18730208, -0.021233026, 0.7417944, -0.4544313, 0.23165174, -0.63969344, 0.09383021, -0.046137553, -0.07796646, 0.11413524));
	result += mul(max(-src[i][j + 1], 0), float4x4(-0.32532063, 0.09456587, 0.43708017, -0.40595353, 0.061229162, 0.006663704, -0.19821976, 0.07661682, -0.21427135, 0.17748164, -0.31958643, 0.3883502, 0.068938896, 0.022886515, 0.022923468, -0.04269318));
	result += mul(max(-src[i + 1][j - 1], 0), float4x4(0.23775512, 0.04026384, 0.12276414, -0.2545085, 0.0894177, 0.115443565, 0.029124375, 0.08887401, -0.0057824687, 0.017655179, -0.025270017, -0.06643964, 0.01316084, 0.024039604, 0.034566984, -0.12682836));
	result += mul(max(-src[i + 1][j], 0), float4x4(0.036596492, 0.22772355, -0.05508538, -0.18005793, -0.06432669, -0.037058707, 0.2718052, -0.10313161, 0.016055575, 0.051271006, -0.038919963, -0.036601298, -0.019457681, 0.03805731, 0.03252896, -0.07179724));
	result += mul(max(-src[i + 1][j + 1], 0), float4x4(0.15046261, 0.13090402, -0.023847125, -0.039356075, 0.045424663, -0.20594294, 0.2154043, -0.18429665, -0.07969159, 0.08719893, -0.057626463, 0.08344988, -0.018651528, 0.047302175, 0.060727824, -0.035960387));
	result += float4(0.04921464, -0.0011432811, 0.062071066, -0.06594219);
	return result;
}

void Pass3(uint2 blockStart, uint3 threadId) {
	uint2 gxy = (Rmp8x8(threadId.x) << 1) + blockStart;
	uint2 inputSize = GetInputSize();
	if (gxy.x >= inputSize.x || gxy.y >= inputSize.y) {
		return;
	}
	float2 inputPt = GetInputPt();

	float4 src[4][4];
	[unroll]
	for (uint i = 0; i < 3; i += 2) {
		[unroll]
		for (uint j = 0; j < 3; j += 2) {
			float2 tpos = (gxy + uint2(i, j)) * inputPt;
			const float4 sr = tex2.GatherRed(sam, tpos);
			const float4 sg = tex2.GatherGreen(sam, tpos);
			const float4 sb = tex2.GatherBlue(sam, tpos);
			const float4 sa = tex2.GatherAlpha(sam, tpos);

			// w z
			// x y
			src[i][j] = float4(sr.w, sg.w, sb.w, sa.w);
			src[i][j + 1] = float4(sr.x, sg.x, sb.x, sa.x);
			src[i + 1][j] = float4(sr.z, sg.z, sb.z, sa.z);
			src[i + 1][j + 1] = float4(sr.y, sg.y, sb.y, sa.y);
		}
	}

	tex1[gxy] = A4KS3(src, 1, 1);
	++gxy.x;
	tex1[gxy] = A4KS3(src, 2, 1);
	++gxy.y;
	tex1[gxy] = A4KS3(src, 2, 2);
	--gxy.x;
	tex1[gxy] = A4KS3(src, 1, 2);
}


//!PASS 4
//!DESC Conv-4x3x3x8, Depth-to-Space
//!IN INPUT, tex1
//!BLOCK_SIZE 16
//!NUM_THREADS 64

float4 A4KS4(float2 pos) {
	float2 inputPt = GetInputPt();

	// [ a, d, g ]
	// [ b, e, h ]
	// [ c, f, i ]
	float4 a = tex1.SampleLevel(sam, pos - inputPt, 0);
	float4 b = tex1.SampleLevel(sam, pos + float2(-inputPt.x, 0), 0);
	float4 c = tex1.SampleLevel(sam, pos + float2(-inputPt.x, inputPt.y), 0);
	float4 d = tex1.SampleLevel(sam, pos + float2(0, -inputPt.y), 0);
	float4 e = tex1.SampleLevel(sam, pos, 0);
	float4 f = tex1.SampleLevel(sam, pos + float2(0, inputPt.y), 0);
	float4 g = tex1.SampleLevel(sam, pos + float2(inputPt.x, -inputPt.y), 0);
	float4 h = tex1.SampleLevel(sam, pos + float2(inputPt.x, 0), 0);
	float4 i = tex1.SampleLevel(sam, pos + float2(inputPt.x, inputPt.y), 0);

	float4 result = mul(max(a, 0), float4x4(-0.04508749, 0.00222134, 0.013338363, -0.0067310617, 0.099346675, 0.05804196, 0.018694466, -0.008126048, 0.007771997, -0.0072556734, -0.008293339, 0.001518462, -0.06296499, -0.064195156, 0.0727399, 0.044078834));
	result += mul(max(b, 0), float4x4(0.20800652, -0.016071903, -0.08095607, -0.03472411, -0.20690396, 0.061331827, -0.10627648, 0.12838624, 0.036534917, -0.006113497, 0.029266752, -0.002263159, 0.2937966, -0.05544609, 0.14546311, -0.01290958));
	result += mul(max(c, 0), float4x4(0.07792222, -7.288649e-05, 0.2800036, 0.019709835, -0.010950291, 0.021879988, 0.037608813, 0.055267945, 0.018646395, -0.016691998, 0.03787624, -0.006547077, 0.03214097, -0.018541625, 0.12142825, -0.070806496));
	result += mul(max(d, 0), float4x4(-0.009798109, -0.06606263, 0.0010101331, 0.009924258, -0.10272075, -0.07983353, 0.028398676, 0.04967719, 0.12467993, 0.06775066, 0.017111637, 0.012814711, 0.0031143876, -0.0902014, 0.11242646, 0.076476306));
	result += mul(max(e, 0), float4x4(0.07650971, 0.35096344, 0.0612814, 0.06036218, 0.253547, -0.0460987, -0.11145313, -0.48844674, -0.050644107, 0.038706005, 0.19390784, 0.035322774, -0.010191005, 0.58071, -0.2856661, -0.009533105));
	result += mul(max(f, 0), float4x4(-0.071486905, -0.036179904, -0.07303894, 0.19301178, -0.11499898, -0.024847068, -0.0027055284, 0.20373714, -0.09671404, -0.020897992, -0.25572056, -0.008931707, -0.13582602, -0.006546881, -0.16154496, 0.26454738));
	result += mul(max(g, 0), float4x4(0.005463064, 0.006769753, 0.0039625713, 0.014121269, -0.068200685, -0.057850275, 0.008622973, 0.061149873, 0.017436448, 0.11660872, -0.02994459, 0.008590145, -0.03223439, 0.052557915, -0.011846354, 0.03523357));
	result += mul(max(h, 0), float4x4(-0.00015264735, 0.0012872831, 0.021878848, 0.022240406, 0.01822283, -0.008284247, -0.018443186, -0.04997753, -0.111760505, -0.20911667, 0.006166832, 0.14597091, 0.02305932, -0.16312876, 0.023375351, -0.028755601));
	result += mul(max(i, 0), float4x4(0.013701143, 0.010794129, 0.0024321147, -0.018976321, 0.0365032, -0.006783485, 0.01046472, -0.08473902, 0.057523903, 0.029831914, 0.0040916028, -0.2046352, 0.03542, -0.034598, 0.0031058635, -0.20746285));
	result += mul(max(-a, 0), float4x4(0.09283864, -0.0035849356, 0.013190911, -0.035437535, 0.035798516, 0.022954805, -0.0029692063, -0.006633743, -0.13456796, -0.011448714, 0.011536131, 0.046695728, -0.0359048, -0.01144856, -0.0027279712, 0.0065755467));
	result += mul(max(-b, 0), float4x4(-0.14295974, -0.0034393691, 0.0051469817, -0.021334402, -0.05882422, -0.003004241, 0.011182507, 0.0015169785, 0.08474255, 0.1255887, -0.23984577, 0.07119401, -0.12547183, 0.038449038, 0.007738907, 0.031506266));
	result += mul(max(-c, 0), float4x4(-0.028237654, 0.010254326, -0.11843009, 0.03034298, -0.038323015, 0.0026470951, -0.060652684, 0.0022312272, -0.022539174, -0.01008126, 0.14868541, 0.02881852, -0.05327277, -0.012296453, -0.21280704, -0.021286633));
	result += mul(max(-d, 0), float4x4(-0.034825645, 0.0877418, -0.009103147, 0.041650586, 0.0135769, -0.005229229, 0.00082947424, -0.0020421906, 0.12402267, 0.007698874, -0.056337915, -0.006580138, -0.018867968, -0.08487179, -0.020938644, -0.029210499));
	result += mul(max(-e, 0), float4x4(-0.37082648, -0.30321857, -0.22912364, -0.07368761, 0.15169628, 0.0013253551, 0.09232649, 0.011408914, 0.06347244, -0.377988, 0.13980117, -0.41065913, -0.00040237256, -0.23220152, -0.03643865, -0.10101427));
	result += mul(max(-f, 0), float4x4(0.10692653, 0.049867555, -0.011915118, -0.10688069, 0.042109665, -0.017163716, 0.10852331, -0.0088934945, 0.06780516, -0.017808875, 0.26564032, 0.0523693, 0.099033475, 0.042864073, 0.18299587, -0.13503626));
	result += mul(max(-g, 0), float4x4(0.07014404, 0.08841395, 0.01895322, 0.0036451078, -0.00933168, 0.044764042, -0.0034986525, 0.010701783, -0.043601245, -0.1375109, 0.0039965697, -0.054331, 0.018830067, 0.040386382, 0.007759782, -0.012478715));
	result += mul(max(-h, 0), float4x4(0.024152381, -0.11462646, 0.07005155, 0.0424638, -0.0048070764, 0.06089261, -0.036675487, 0.057459857, 0.02478629, 0.2926517, -0.08248396, -0.053960845, 0.013205341, 0.09851673, -0.04310949, -0.001428641));
	result += mul(max(-i, 0), float4x4(0.016168298, 0.009701502, 0.0064305146, -0.068672284, -0.044653386, -0.016051823, -0.015055443, 0.032019246, -0.0829852, -0.011304939, 0.0023902296, 0.30322486, -0.023831543, -0.0046928846, 0.026961725, 0.16314326));
	result += float4(-0.0031417734, -0.002754766, -0.004053268, -0.003937834);
	return result;
}

void Pass4(uint2 blockStart, uint3 threadId) {
	uint2 gxy = (Rmp8x8(threadId.x) << 1) + blockStart;

	if (!CheckViewport(gxy)) {
		return;
	}

	float2 inputPt = GetInputPt();
	float2 outputPt = GetOutputPt();

	float2 pos = ((gxy >> 1) + 0.5f) * inputPt;
	float4 c = A4KS4(pos);

	pos -= 0.5f * outputPt;
	WriteToOutput(gxy, c.x + INPUT.SampleLevel(sam1, pos, 0).rgb);

	gxy.x += 1u;
	pos.x += outputPt.x;
	if (CheckViewport(gxy)) {
		WriteToOutput(gxy, c.y + INPUT.SampleLevel(sam1, pos, 0).rgb);
	}

	gxy.y += 1u;
	pos.y += outputPt.y;
	if (CheckViewport(gxy)) {
		WriteToOutput(gxy, c.w + INPUT.SampleLevel(sam1, pos, 0).rgb);
	}

	gxy.x -= 1u;
	pos.x -= outputPt.x;
	if (CheckViewport(gxy)) {
		WriteToOutput(gxy, c.z + INPUT.SampleLevel(sam1, pos, 0).rgb);
	}
}
