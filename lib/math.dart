part of webgl_framework;

// http://www.euclideanspace.com/maths/algebra/realNormedAlgebra/quaternions/slerp/
Quaternion slerpQuaternion(Quaternion qa, Quaternion qb, double t) {
// quaternion to return
  Quaternion qm = new Quaternion.identity();

// Calculate angle between them.
  double cos_half_theta = qa.w * qb.w + qa.x * qb.x + qa.y * qb.y + qa.z * qb.z;

// if qa=qb or qa=-qb then theta = 0 and we can return qa
  if (cos_half_theta.abs() >= 1.0){
    qm.w = qa.w;
    qm.x = qa.x;
    qm.y = qa.y;
    qm.z = qa.z;
    return qm;
  }

// Calculate temporary values.
  double half_theta = Math.acos(cos_half_theta);
  double sin_half_theta = Math.sqrt(1.0 - cos_half_theta*cos_half_theta);

// if theta = 180 degrees then result is not fully defined
// we could rotate around any axis normal to qa or qb
  if (sin_half_theta.abs() < 0.001){ // fabs is floating point absolute
    qm.w = (qa.w * 0.5 + qb.w * 0.5);
    qm.x = (qa.x * 0.5 + qb.x * 0.5);
    qm.y = (qa.y * 0.5 + qb.y * 0.5);
    qm.z = (qa.z * 0.5 + qb.z * 0.5);
    return qm;
  }
  double ratio_a = Math.sin((1 - t) * half_theta) / sin_half_theta;
  double ratio_b = Math.sin(t * half_theta) / sin_half_theta;

//calculate Quaternion.
  qm.w = (qa.w * ratio_a + qb.w * ratio_b);
  qm.x = (qa.x * ratio_a + qb.x * ratio_b);
  qm.y = (qa.y * ratio_a + qb.y * ratio_b);
  qm.z = (qa.z * ratio_a + qb.z * ratio_b);

  return qm;
}

