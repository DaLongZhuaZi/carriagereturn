/** 机型蓝图接口（§14）：各机型各自实现，蓝图之间零引用。 */
export interface MachineBlueprint {
  /** 拨杆层宽 = Hc × 1.84 × 此值（平板）／h × 此值（手机） */
  leverSizeRatio: number;
  /** 拨杆图宽高比（LeverLayer 用它算杆长） */
  leverAspect: number;
  /** 支架图宽高比 */
  bracketAspect: number;
  /** 支架销钉孔 x／y 比例 */
  bracketPivotX: number;
  bracketPivotY: number;
  /** 拨杆支点孔 y 比例 */
  leverPivotY: number;
  /** 拨杆支架素材（各机型各自字面量，$rawfile 只吃编译期常量） */
  bracketRawfile: () => Resource;
}